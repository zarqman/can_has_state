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
      unless method_defined? :state_machines
        class_attribute :state_machines, instance_writer: false, default: {}
      end
      before_validation :can_has_initial_states
      before_validation :can_has_state_triggers
      validate :can_has_valid_state_machines
      after_save :can_has_deferred_state_triggers if respond_to?(:after_save)
    end


    private

    def can_has_initial_states
      state_machines.each do |column, sm|
        if send(column).blank?
          send("#{column}=", sm.initial_state)
        end
      end
    end

    def can_has_state_triggers
      @triggers_called = {}

      # skip triggers if any state machine isn't valid
      return if can_has_state_errors.any?

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
        end
      end
    end

    def can_has_deferred_state_triggers
      state_machines.each do |column, sm|
        if respond_to?("#{column}_before_last_save") # rails 5.1+
          from, to = send("#{column}_before_last_save"), send(column)
        else
          from, to = send("#{column}_was"), send(column)
        end
        next if from == to

        @triggers_called[column] ||= []
        triggers = sm.triggers_for(from: from, to: to, deferred: true)

        triggers.each do |trigger|
          next if @triggers_called[column].include? trigger

          trigger.call self
          @triggers_called[column] << trigger
        end
      end
    end

    def can_has_state_errors
      err = []
      state_machines.each do |column, sm|
        from, to = send("#{column}_was"), send(column)
        next if from == to
        if !sm.known?(to)
          err << [column, :invalid_state]
        elsif !sm.allow?(self, to) #state_machine_allow?(column, to)
          err << [column, sm.message(to), {from: from, to: to}]
        end
      end
      err
    end

    def can_has_valid_state_machines
      can_has_state_errors.each do |(column, msg, opts)|
        errors.add column, msg, **(opts||{})
      end
    end

    def state_machine_allow?(column, to)
      sm = state_machines[column.to_sym] || raise("Unknown state machine #{column}")
      sm.allow?(self, to)
    end

  end
end
