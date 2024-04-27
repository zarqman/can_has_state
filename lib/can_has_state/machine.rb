module CanHasState
  module Machine
    extend ActiveSupport::Concern

    module ClassMethods

      def state_machine(column, &block)
        column = column.to_sym
        raise(ArgumentError, "State machine for #{column} already exists") if state_machines.key?(column)

        d = Definition.new(column, self, &block)

        define_method "allow_#{column}?" do |to|
          state_machine_allow?(column.to_sym, to.to_s)
        end

        self.state_machines = state_machines.merge(column => d)
        column
      end

      def extend_state_machine(column, &block)
        column = column.to_sym
        sm = state_machines[column] || raise(ArgumentError, "Unknown state machine #{column}")

        # handle when sm is inherited from a parent class
        if sm.parent_context != self
          sm = sm.dup
          sm.parent_context = self
          self.state_machines = state_machines.merge(column => sm)
        end

        sm.extend_machine(&block)
        column
      end

    end

    included do
      class_attribute :state_machines, instance_writer: false, default: {}
      before_validation :set_initial_state_machine_values
      before_validation :reset_state_triggers
      before_validation :run_state_triggers
      validate :validate_state_machines
      after_save :run_deferred_state_triggers if respond_to?(:after_save)
    end


    private

    def set_initial_state_machine_values
      state_machines.each do |column, sm|
        if send(column).blank?
          send("#{column}=", sm.initial_state)
        end
      end
    end

    def reset_state_triggers
      @triggers_called = {}
    end

    def run_state_triggers
      # skip triggers if any state machine isn't valid
      return if can_has_state_errors.any?

      state_machines.size.times do
        called = false
        state_machines.each do |column, sm|
          from, to = send("#{column}_was"), send(column)
          next if from == to

          @triggers_called[column] ||= []
          triggers = sm.triggers_for(from: from, to: to)

          triggers.each do |trigger|
            # skip trigger if it's already been called
            next if @triggers_called[column].include? trigger

            trigger.call self
            @triggers_called[column] << trigger
            called = true
          end
        end
        break unless called
      end
    end

    def run_deferred_state_triggers
      tg = @triggers_called ||= {}
        # if a trigger causes a circular save, @triggers_called can be reset mid-stream,
        # causing `... << trigger` at the bottom to fail. this ensure we have a local
        # copy that won't be reset.

      state_machines.each do |column, sm|
        from, to = send("#{column}_before_last_save"), send(column)
        next if from == to

        tg[column] ||= []
        triggers = sm.triggers_for(from: from, to: to, deferred: true)

        triggers.each do |trigger|
          next if tg[column].include? trigger

          trigger.call self
          tg[column] << trigger
        end
      end
    end

    def can_has_state_errors(reset: true)
      @can_has_state_errors = {} if reset || !@can_has_state_errors
      state_machines.each do |column, sm|
        from, to = send("#{column}_was"), send(column)
        if !sm.known?(to)
          @can_has_state_errors[column] = [:invalid_state]
        elsif from == to
          next
        elsif !sm.allow?(self, to) #state_machine_allow?(column, to)
          @can_has_state_errors[column] = [sm.message(to), {from: "'#{from}'", to: "'#{to}'"}]
        end
      end
      @can_has_state_errors
    end

    def validate_state_machines
      can_has_state_errors(reset: false).each do |column, (msg, opts)|
        errors.add column, msg, **(opts||{})
      end
    end

    def state_machine_allow?(column, to)
      sm = state_machines[column.to_sym] || raise("Unknown state machine #{column}")
      sm.allow?(self, to)
    end

  end
end
