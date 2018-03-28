module CanHasState
  module Machine
    extend ActiveSupport::Concern

    module ClassMethods

      def state_machine(column, &block)
        d = Definition.new(column, self, &block)

        define_method "allow_#{column}?" do |to|
          state_machine_allow?(column.to_sym, to.to_s)
        end

        self.state_machines += [[column.to_sym, d]]
      end

      def extend_state_machine(column, &block)
        sm = state_machines.detect{|(col, _)| col == column}
          # |(col, stm)|
        raise(ArgumentError, "Unknown state machine #{column}") unless sm
        sm[1].extend_machine(&block)
        sm
      end

    end

    included do
      unless method_defined? :state_machines
        class_attribute :state_machines, :instance_writer=>false
        self.state_machines = []
      end
      before_validation :can_has_initial_states
      before_validation :can_has_state_triggers
      validate :can_has_valid_state_machines
      after_save :can_has_deferred_state_triggers if respond_to?(:after_save)
    end


    private

    def can_has_initial_states
      state_machines.each do |(column, sm)|
        if send(column).blank?
          send("#{column}=", sm.initial_state)
        end
      end
    end

    def can_has_state_triggers
      # skip triggers if any state machine isn't valid
      return if can_has_state_errors.any?

      @triggers_called ||= {}
      state_machines.each do |(column, sm)|
        from, to = send("#{column}_was"), send(column)
        next if from == to

        # skip triggers if they've already been called for this from/to transition
        next if @triggers_called[column] == [from, to]

        sm.trigger(self, from, to)

        # record that triggers were called
        @triggers_called[column] = [from, to]
      end
    end

    def can_has_deferred_state_triggers
      @triggers_called ||= {}
      state_machines.each do |(column, sm)|
        # clear record of called triggers
        @triggers_called[column] = nil
        
        if respond_to?("#{column}_before_last_save") # rails 5.1+
          from, to = send("#{column}_before_last_save"), send(column)
        else
          from, to = send("#{column}_was"), send(column)
        end
        next if from == to
        sm.trigger(self, from, to, :deferred)
      end
    end

    def can_has_state_errors
      err = []
      state_machines.each do |(column, sm)|
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
        errors.add column, msg, opts||{}
      end
    end

    def state_machine_allow?(column, to)
      sm = state_machines.detect{|(col, _)| col == column}
        # |(col, stm)|
      raise("Unknown state machine #{column}") unless sm
      sm[1].allow?(self, to)
    end

  end
end
