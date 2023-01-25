require 'test_helper'

class Skeleton
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include CanHasState::DirtyHelper
  include CanHasState::Machine

  track_dirty :state

  state_machine :state do
    state :awesome
    state :fabulous, :initial
  end

  def self.after_save(...)
    # dummy to allow deferred triggers
  end

  def fake_persist
    if valid?
      # reset dirty tracking as if we had persisted
      changes_applied
      true
    end
  end
end

class Account
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include CanHasState::DirtyHelper
  include CanHasState::Machine

  attr_accessor :deleted_at, :undeleted, :allow_special
  track_dirty :account_state

  state_machine :account_state do
    state :active,
      from: [:inactive, :special]
    state :special,
      require: :allow_special
    state :inactive,
      from: [:active, :deleted, :special]
    state :deleted,
      from: [:active, :inactive],
      timestamp: :deleted_at
    on :deleted => :*, trigger: ->(acct){ acct.undeleted = true }
  end

  def fake_persist
    if valid?
      # reset dirty tracking as if we had persisted
      changes_applied
      true
    end
  end
end

class UserBare ; end
class UserState
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include CanHasState::Machine
  state_machine :state do
    state :awesome
    state :fabulous, :initial
  end
end

class UserPreState
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include CanHasState::Machine
end
class UserPreState2
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include CanHasState::Machine
  def self.after_save(*_)
    # dummy to allow deferred triggers
  end
end

class CanHasStateTest < Minitest::Test

  def test_builder_simple
    refute UserBare.respond_to?(:state_machine)
    assert UserState.respond_to?(:state_machine)
    assert UserState.respond_to?(:state_machines)
    assert UserState.new.respond_to?(:allow_state?)
    assert_equal 1, UserState.state_machines.size
    sm = UserState.state_machines[:state]
    assert_equal :state, sm.column
    assert_equal 2, sm.states.size
    assert_equal 0, sm.triggers.size
    assert_equal 'fabulous', sm.initial_state
  end

  def test_invalid_state_option
    assert_raises(ArgumentError) do
      build_from_skeleton do
        state_machine :color do
          state :red,
            made_up: :option
        end
      end
    end
  end

  def test_builder_extended
    kl = build_from_skeleton do
      extend_state_machine :state do
        state :incredible, :initial
      end
      extend_state_machine :state do
        state :fantastic
      end
    end

    assert_equal 1, kl.state_machines.size
    sm = kl.state_machines[:state]
    assert_equal :state, sm.column
    assert_equal 4, sm.states.size
    assert_equal 0, sm.triggers.size
    assert_equal 'incredible', sm.initial_state
  end

  def test_extending
    assert_raises(ArgumentError) do
      build_from_skeleton do
        extend_state_machine :doesnt_exist do
          state :phantom
        end
      end
    end
  end

  def test_extending_child_doesnt_affect_parent
    child = build_from_skeleton do
      attr_accessor :trigger_called
      extend_state_machine :state do
        on :* => :*, trigger: ->(r){ r.trigger_called = true}
      end
    end
    assert_equal 0, Skeleton.state_machines[:state].triggers.size
    assert_equal 1, child.state_machines[:state].triggers.size

    m = Skeleton.new
    m.state = 'awesome'
    refute m.respond_to?(:trigger_called=)
    assert m.fake_persist
    # should not raise error calling trigger_called=

    m = child.new
    m.state = 'awesome'
    assert m.fake_persist
    assert_equal true, m.trigger_called
  end


  def test_deferred_unavailable
    assert_raises(ArgumentError) do
      UserPreState.class_eval do
        state_machine :state_one do
          state :one, on_enter_deferred: proc{ raise "Shouldn't get here" }
        end
      end
    end

    assert_raises(ArgumentError) do
      UserPreState.class_eval do
        state_machine :state_two do
          state :two, on_exit_deferred: proc{ raise "Shouldn't get here" }
        end
      end
    end

    assert_raises(ArgumentError) do
      UserPreState.class_eval do
        state_machine :state_three do
          state :three
          on :* => :*, trigger: proc{ raise "Shouldn't get here" }, deferred: true
        end
      end
    end
  end

  def test_deferred_available
    UserPreState2.class_eval do
      state_machine :state_one do
        state :one, on_enter_deferred: proc{ puts 'Hello' }
      end
    end

    UserPreState2.class_eval do
      state_machine :state_two do
        state :two, on_exit_deferred: proc{ puts 'Hello' }
      end
    end

    UserPreState2.class_eval do
      state_machine :state_three do
        state :three
        on :* => :*, trigger: proc{ puts 'Hello' }, deferred: true
      end
    end
  end


  def test_builder_complex
    assert_equal 1, Account.state_machines.size
    sm = Account.state_machines[:account_state]
    assert_equal :account_state, sm.column
    assert_equal 4, sm.states.size
    assert_equal 2, sm.triggers.size
    assert_equal 'active', sm.initial_state
  end

  def test_state_builder
    sm_acct = Account.state_machines[:account_state]
    sm_user = UserState.state_machines[:state]
    assert_equal 0, sm_user.states['awesome'][:guards].size
    assert_equal 1, sm_acct.states['active'][:guards].size
  end


  def test_dirty_helper
    assert Account.new.respond_to?(:account_state)
    assert Account.new.respond_to?(:account_state_was)

    a = Account.new
    a.fake_persist
    assert_equal 'active', a.account_state
    assert_equal 'active', a.account_state_was
    a.account_state = 'inactive'
    assert_equal 'inactive', a.account_state
    assert_equal 'active', a.account_state_was
    a.fake_persist
    assert_equal 'inactive', a.account_state
    assert_equal 'inactive', a.account_state_was
  end


  def test_state_vals
    a = Account.new
    a.account_state = :inactive
    assert a.valid?, "Should be valid; got errors: #{a.errors.to_a}"

    a = Account.new
    a.account_state = 'inactive'
    assert a.valid?, "Should be valid; got errors: #{a.errors.to_a}"

    a = Account.new
    a.account_state = 'madeup'
    refute a.valid?
    assert_equal ['Account state is not in a known state'], a.errors.to_a
  end

  def test_state_with_invalid_default
    kl = build_from_skeleton do
      include ActiveModel::Attributes
      attribute :state, :string, default: 'madeup'
    end

    m = kl.new
    assert_equal 'madeup', m.state
    refute m.valid?
    assert m.errors.of_kind?(:state, :invalid_state)
  end


  def test_triggers
    a = Account.new
    a.fake_persist
    assert_equal 'active', a.account_state
    refute a.deleted_at
    refute a.undeleted

    a.account_state = 'deleted'
    assert a.fake_persist
    assert_kind_of Time, a.deleted_at
    refute a.undeleted

    a.account_state = 'inactive'
    assert a.fake_persist, "Unexpected error: #{a.errors.to_a}"
    assert a.undeleted, 'Expecting undeleted to be set'
  end

  def test_trigger_symbol
    kl = build_from_skeleton do
      attr_accessor :trigger_called
      extend_state_machine :state do
        on :* => :*, trigger: :call_trigger
      end
      def call_trigger
        self.trigger_called = true
      end
    end
    a = kl.new
    refute a.trigger_called

    a.state = 'awesome'
    assert a.fake_persist
    assert a.trigger_called
  end

  def test_trigger_proc_arity_0
    kl = build_from_skeleton do
      attr_accessor :trigger_called
      extend_state_machine :state do
        on :* => :*, trigger: Proc.new{self.trigger_called = true}
      end
    end
    a = kl.new
    refute a.trigger_called

    a.state = 'awesome'
    assert a.fake_persist
    assert a.trigger_called
  end

  def test_trigger_proc_arity_1
    kl = build_from_skeleton do
      attr_accessor :trigger_called
      extend_state_machine :state do
        on :* => :*, trigger: lambda{|r| r.trigger_called = true}
      end
    end
    a = kl.new
    refute a.trigger_called

    a.state = 'awesome'
    assert a.fake_persist
    assert a.trigger_called
  end


  def test_transition_messagea_when_from_nil
    a = Account.new
    a.account_state = 'special'
    a.validate
    assert_match(/has an invalid transition from '' to 'special'/, a.errors.to_a.first)
  end

  def test_guards
    a = Account.new
    a.account_state = 'deleted'
    assert a.fake_persist

    a.account_state = 'active'
    a.valid?
    assert_match(/invalid transition/, a.errors.to_a.first)

    a.account_state = 'inactive'
    assert a.valid?, "Errors: #{a.errors.to_a}"


    a.account_state = 'special'
    a.valid?
    assert_match(/invalid transition/, a.errors.to_a.first)

    a.allow_special = true
    assert a.valid?, "Errors: #{a.errors.to_a}"
  end


  def test_interacting_triggers
    kl = build_from_skeleton do
      track_dirty :mood, :outlook
      attr_accessor :called_on_state, :called_on_mood, :called_on_outlook
      extend_state_machine :state do
        on :* => :awesome, trigger: proc{ self.called_on_state += 1 }
      end
      state_machine :mood do
        state :happy
        state :delighted,
          on_enter: proc{
            self.state = 'awesome'
            self.outlook = 'outstanding'
            self.called_on_mood += 1
          }
      end
      state_machine :outlook do
        state :positive
        state :outstanding
        on :positive => :*, trigger: proc{ self.called_on_outlook += 1 }
      end
      def initialize
        @called_on_state   = 0
        @called_on_mood    = 0
        @called_on_outlook = 0
      end
    end
    m = kl.new
    assert m.fake_persist
    assert_equal 0, m.called_on_mood
    assert_equal 0, m.called_on_outlook
    assert_equal 0, m.called_on_state

    m.mood = 'delighted'
    assert m.fake_persist
    assert_equal 1, m.called_on_mood
    assert_equal 1, m.called_on_outlook, 'should trigger on later state_machines'
    assert_equal 1, m.called_on_state, 'should trigger on earlier state_machines'
  end



  def build_from_skeleton(&block)
    Class.new(Skeleton).tap do |kl|
      kl.class_eval(&block)
    end
  end

end
