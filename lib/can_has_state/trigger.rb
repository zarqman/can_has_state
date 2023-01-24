module CanHasState
  class Trigger

    attr_accessor :state_machine
    attr_reader :from, :to, :type, :deferred, :perform

    def initialize(definition, from:, to:, type:, deferred: false, trigger:)
      @state_machine = definition
      @from          = Array(from).map{|v| v&.to_s}
      @to            = Array(to).map{|v| v&.to_s}
      @type          = type
      @deferred      = !!deferred
      @perform       = Array(trigger)

      if @deferred && !state_machine.parent_context.respond_to?(:after_save)
        raise ArgumentError, 'use of deferred triggers requires support for #after_save callbacks'
      end
      @perform.each do |m|
        unless [Proc, String, Symbol].include?(m.class)
          raise ArgumentError, "Expecing Symbol or Proc for #{@type.inspect}, got #{m.class} : #{m}"
        end
      end
    end

    def matches?(from:, to:, deferred: false)
      matches_from?(from) &&
        matches_to?(to) &&
        matches_deferred?(deferred)
    end

    def call(record)
      perform.each do |m|
        case m
        when Proc
          m.call record
        when Symbol, String
          record.send m
        end
      end
    end


    private

    def matches_from?(state)
      from.include?('*') || from.include?(state)
    end

    def matches_to?(state)
      to.include?('*') || to.include?(state)
    end

    def matches_deferred?(defer)
      defer ? self.deferred : !self.deferred
    end

  end
end
