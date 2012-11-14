module CanHasState
  class Definition

    attr_reader :column, :states, :initial_state, :triggers

    def initialize(column_name, &block)
      @column = column_name.to_sym
      @states = {}
      @triggers = []
      instance_eval &block
      @initial_state ||= @states.keys.first
    end


    def extend_machine(&block)
      instance_eval &block
    end


    def state(state_name, *args)
      options = args.extract_options!
      state_name = state_name.to_s

      if args.include? :initial
        @initial_state = state_name
      end

      # TODO: turn even guards into types of triggers ... then support :guard as a trigger param
      guards = []
      message = "has invalid transition from %{from} to %{to}"
      # TODO: differentiate messages for :from errors vs. :guard errors

      options.each do |key, val|
        case key
        when :from
          from_vals = Array(val).map(&:to_s)
          from_vals << nil # for new records
          guards << Proc.new{|r| from_vals.include? r.send("#{column}_was").try(:to_s)}
        when :guard, :require
          guards += Array(val)
        when :message
          message = val
        when :timestamp
          @triggers << {:from=>["*"], :to=>[state_name], :trigger=>[Proc.new{|r| r.send("#{val}=", Time.current)}]}
        when :on_enter
          @triggers << {:from=>["*"], :to=>[state_name], :trigger=>Array(val), :type=>:on_enter}
        when :on_enter_deferred
          @triggers << {:from=>["*"], :to=>[state_name], :trigger=>Array(val), :type=>:on_enter, :deferred=>true}
        when :on_exit
          @triggers << {:from=>[state_name], :to=>["*"], :trigger=>Array(val), :type=>:on_exit}
        when :on_exit_deferred
          @triggers << {:from=>[state_name], :to=>["*"], :trigger=>Array(val), :type=>:on_exit, :deferred=>true}
        end
      end

      @states[state_name] = {:guards=>guards, :message=>message}
    end


    def on(pairs)
      trigger  = pairs.delete :trigger
      deferred = pairs.delete :deferred
      pairs.each do |from, to|
        @triggers << {:from=>Array(from).map(&:to_s), :to=>Array(to).map(&:to_s), 
                      :trigger=>Array(trigger), :type=>:trigger, :deferred=>!!deferred}
      end
    end



    def known?(to)
       @states.keys.include? to
    end

    def allow?(record, to)
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
      states[to][:message]
    end


    def trigger(record, from, to, deferred=false)
      # Rails.logger.debug "Checking triggers for transition #{from} to #{to} (deferred:#{deferred.inspect})"
      @triggers.select do |trigger|
        deferred ? trigger[:deferred] : !trigger[:deferred]
      end.select do |trigger|
        (trigger[:from].include?("*") || trigger[:from].include?(from)) &&
            (trigger[:to].include?("*") || trigger[:to].include?(to))
      # end.each do |trigger|
      #   Rails.logger.debug "  Matched trigger: #{trigger[:from].inspect} -- #{trigger[:to].inspect}"
      end.each do |trigger|
        call_triggers record, trigger
      end
    end


    private

    def call_triggers(record, trigger)
      trigger[:trigger].each do |m|
        case m
        when Proc
          m.call record
        when Symbol, String
          record.send m
        else
          raise ArgumentError, "Expecing Symbol or Proc for #{trigger[:type].inspect}, got #{m.class} : #{m}"
        end
      end
    end

  end
end
