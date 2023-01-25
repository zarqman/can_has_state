module CanHasState
  class Definition

    attr_accessor :parent_context
    attr_reader :column, :states, :triggers, :initial_state

    def initialize(column_name, model_class, &block)
      @parent_context = model_class
      @column = column_name.to_sym
      @states = {}
      @triggers = []
      instance_eval(&block)
      @initial_state ||= @states.keys.first
    end

    def initialize_dup(orig)
      @states = @states.deep_dup
      @triggers = @triggers.map do |t|
        t = t.dup
        t.state_machine = self
        t
      end
      super
    end


    def extend_machine(&block)
      instance_eval(&block)
    end


    def state(state_name, *args)
      options = args.extract_options!
      state_name = state_name.to_s

      if args.include? :initial
        @initial_state = state_name
      end

      # TODO: turn even guards into types of triggers ... then support :guard as a trigger param
      guards = []
      message = :invalid_transition
      # TODO: differentiate messages for :from errors vs. :guard errors

      options.each do |key, val|
        case key
        when :from
          from_vals = Array(val).map(&:to_s)
          from_vals << nil # for new records
          guards << Proc.new do |r|
            val_was = r.send("#{column}_was")
            val_was &&= val_was.to_s
            from_vals.include? val_was
          end
        when :guard, :require
          guards += Array(val)
        when :message
          message = val
        when :timestamp
          @triggers << Trigger.new(self, from: '*', to: state_name, trigger: Proc.new{|r| r.send("#{val}=", Time.now.utc)}, type: :timestamp)
        when :on_enter
          @triggers << Trigger.new(self, from: '*', to: state_name, trigger: val, type: :on_enter)
        when :on_enter_deferred
          @triggers << Trigger.new(self, from: '*', to: state_name, trigger: val, type: :on_enter, deferred: true)
        when :on_exit
          @triggers << Trigger.new(self, from: state_name, to: '*', trigger: val, type: :on_exit)
        when :on_exit_deferred
          @triggers << Trigger.new(self, from: state_name, to: '*', trigger: val, type: :on_exit, deferred: true)
        else
          raise ArgumentError, "Unknown argument #{key.inspect}"
        end
      end

      @states[state_name] = {:guards=>guards, :message=>message}
    end


    def on(pairs)
      trigger  = pairs.delete :trigger
      deferred = pairs.delete :deferred
      pairs.each do |from, to|
        @triggers << Trigger.new(self, from: from, to: to, trigger: trigger, type: :trigger, deferred: deferred)
      end
    end



    def known?(to)
      to &&= to.to_s
      @states.keys.include? to
    end

    def allow?(record, to)
      to &&= to.to_s
      return false unless known?(to)
      states[to][:guards].all? do |g|
        case g
        when Proc
          g.call record
        when Symbol, String
          record.send g
        else
          raise ArgumentError, "Expecing Symbol or Proc for :guard, got #{g.class} : #{g}"
        end
      end
    end

    def message(to)
      to &&= to.to_s
      states[to][:message]
    end


    # conditions - :deferred
    def triggers_for(from:, to:, **conditions)
      from = from&.to_s
      to   = to&.to_s
      # Rails.logger.debug "Checking triggers for transition #{from.inspect} to #{to.inspect} (#{conditions.inspect})"
      @triggers.select do |trigger|
        trigger.matches? from: from, to: to, **conditions
      # end.each do |trigger|
      #   Rails.logger.debug "  Matched trigger: #{trigger.from.inspect} -- #{trigger.to.inspect}"
      end
    end

  end
end
