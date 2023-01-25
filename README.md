# CanHasState


`can_has_state` is a simplified state machine gem. It relies on ActiveModel and
should be compatible with any ActiveModel-compatible persistence layer.

Key features:

* Support for multiple state machines
* Simplified DSL syntax
* Few added methods avoids clobbering up model's namespace
* Compatible with ActionPack-style attribute value changes via  
  `state_column: 'new_state'`
* Use any ActiveModel-compatible persistence layer (including your own)



## Installation

Add it to your `Gemfile`:

    gem 'can_has_state'


## DSL

### ActiveRecord

    class Account < ActiveRecord::Base

      # Choose your state column name. In this case, it's :state.
      #   It's super easy to have multiple state machines.
      #
      state_machine :state do

        # Define each possible state. Add :initial to indicate which state
        #   will be selected first, if the state hasn't been already set. If 
        #   not provided, will set :initial to the first defined state.
        #
        # :on_enter and :on_exit trigger when this state is entered / exited.
        #   Symbols are assumed to be instance method names. Inline blocks may
        #   also be specified. The _deferred variations are discussed below
        #   under triggers.
        #
        state :active, :initial,
          from: :inactive,
          on_enter: :update_plan_details,
          on_enter_deferred: :start_billing,
          on_exit_deferred: lambda{|r| r.stop_billing }

        # :from restricts which states can switch to this one. Multiple "from"
        #   states are allowed, as shown below under `state :deleted`.
        #
        # If :from is not present, this state may be entered from any other
        #   state. To prevent ever moving to a given state (only useful if that
        #   state is also the initial state), use `from: []`.
        #
        state :inactive,
          from: [:active]

        # :timestamp automatically sets the current date/time when this state
        #   is entered. Both *_at and *_on (datetime and date) columns are
        #   supported.
        #
        # :require adds additional restrictions before this state can be
        #   entered. Like :on_enter/:on_exit, it can be a method name or a
        #   lambda/Proc. Multiple methods may be provided. Each method must
        #   return a ruby truthy value (anything except nil or false) for the
        #   condition to be satisfied. If any :require is not true, then the
        #   state transition is blocked.
        #
        # :message allows the validation error message to be customized. It is
        #   used when conditions for either :from or :require fail. The default
        #   message is used in the example below. %{from} and %{to} parameters
        #   are optional, and will be the old (from) and new (to) values of the
        #   state field.
        #
        state :deleted,
          from: [:active, :inactive],
          timestamp: :deleted_at,
          on_enter_deferred: [:delete_record, :delete_payment_info],
          require: proc{ !active_services? },
          message: "has invalid transition from %{from} to %{to}"

        # Custom triggers are called for certain "from" => "to" state
        #   combinations. They are especially useful for DRYing up triggers
        #   that apply in multiple situations. They can also be used to apply
        #   triggers only in narrower situations than :on_enter/:on_exit above.

        # This triggers *only* on :inactive => :active. It will not trigger on
        #   nil => :active (setting initial state) [see notes on triggers and
        #   initial state below].
        #
        on :inactive => :active, :trigger => :send_welcome_back_message

        # Multiple triggers can be specified on either side of the transition
        #   or for the trigger actions:
        #
        on [:active, :inactive] => :deleted, trigger: [:do_one, :do_two]
        on :active => [:inactive, :deleted], trigger: ->(r){ r.act }

        # If :deferred is included, and it's true, then this trigger will
        #   happen post-save, instead of pre-validation. Default pre-validation
        #   triggers are recommended for changing other attributes. Post-save
        #   triggers are useful for logging or cascading changes to association
        #   models. Deferred trigger actions are run within the same database
        #   transaction (for ActiveRecord and other ActiveModel children that
        #   implement this). Deferred triggers require support for after_save
        #   callbacks, compatible with that supported by ActiveRecord.
        #
        # Last, wildcards are supported. Note that the ruby parser requires a
        #   space after the asterisk for wildcards on the left side:
        #   works:    :* =>:whatever
        #   doesn't:  :*=>:whatever
        #
        # Utilize ActiveModel::Dirty's change history support to know what has
        #   changed:
        #   from = state_was   # (specifically, <state_column>_was)
        #   to   = state
        #
        on :* => :*, trigger: :log_state_change, deferred: true
        on :* => :deleted, trigger: :same_as_on_enter

      end

    end


### Just ActiveModel

    class Account
      include CanHasState::DirtyHelper
      include ActiveModel::Validations
      include ActiveModel::Validations::Callbacks
      include CanHasState::Machine

      track_dirty :account_state

      state_machine :account_state do
        state :active, :initial,
          from: :inactive
        state :inactive,
          from: :active
        state :deleted,
          from: [:active, :inactive],
          timestamp: :deleted_at
      end

    end

ActiveModel::Dirty tracking must be enabled for the attribute(s) that hold the
state(s) in your model (see docs for ActiveModel::Dirty). If you're building on
top of a library that supports this (ActiveRecord, Mongoid, etc.), you're fine.
If not, CanHasState provides a helper module, `CanHasState::DirtyHelper`, that
provides the supporting implementation required by ActiveModel::Dirty. Just call
`track_dirty :attr_one, :attr_two` as shown above.

Hint: deferred triggers aren't supported with bare ActiveModel. However, if a
non-ActiveRecord persistence engine provides #after_save, then deferred triggers
will be enabled.


## Managing states

States are set directly via the relevant state column--no added methods.

    @account = Account.new
    @account.save!
    @account.state
    # => 'active'

    @account.state = 'deleted'
    @account.valid?
    # => true
    @account.save!

    @account.state = 'active'
    @account.valid?
    # => false


With multiple state machines on a single model, this also eliminates any name
collisions.

    class Account < ActiveRecord::Base

      # column is :state
      state_machine :state do
        state :active,
          from: :inactive,
          require: lambda{|r| r.payment_status=='current'}
        state :inactive,
          from: :active
        state :deleted,
          from: [:active, :inactive]
      end

      # column is :payment_status
      state_machine :payment_status do
        state :pending, :initial
        state :current
        state :overdue
      end
    end

    @account = Account.new
    @account.save!
    @account.state
    # => 'active'
    @account.payment_status
    # => 'pending'

    @account.state = 'inactive'
    @account.payment_status = 'overdue'
    @account.save!


You can also check a potential state change using the method  
`"allow_#{state_machine_column_name}?(potential_state)"`.

    @account.allow_state? :active
    # => false
    @account.allow_payment_status? :pending
    # => true


If you really want event-changing methods, it's just as straight-forward to
write them as normal methods instead of attempting to cram them into a DSL.

    def delete!
      self.state = 'deleted'
      save!
    end

When `save!` is called, the state changes will be validated and all triggers
will be called.



## Using triggers on initial states

`can_has_state` relies on the `ActiveModel::Dirty` module to detect when a state
attribute has changed. In general, this shouldn't matter much to you as long as
you're using ActiveRecord, Mongoid, or something that implements full Dirty
support.

However, triggers involving initial values can be tricky. If your database
schema sets the default value to the initial value, `:on_enter` and custom
triggers will *not* be called because nothing has changed. On the other hand,
if the state column defaults to a null value, then the triggers will be called
because the initial state value changed from nil to the initial state.



## Modifying state attributes in `before_validation`

`can_has_state`'s validation callbacks run very early, almost always before any
Model-specific validation. This ensures that validations and normal callbacks
see the model's attributes after any triggers have been run.

This can cause problems when modifying the value of a state attribute as part of
a callback. The most common way this shows up is receiving state validation
errors (typically due to a `:require`), even when a `before_validation` callback
seems to be executed.

Often, the best solution is to review the modification of state attributes
during callbacks, as the original problem can hint at code design issue. If the
callbacks are definitely warranted, try moving your validation to the start of
the callback chain so it runs before `can_has_state`:

    before_validation :some_method, prepend: true
