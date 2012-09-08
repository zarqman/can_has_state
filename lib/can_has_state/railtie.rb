module CanHasState
  class Railtie < Rails::Railtie

    initializer "can_has_state" do |app|
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.send :include, CanHasState::Machine
      end
    end

  end
end
