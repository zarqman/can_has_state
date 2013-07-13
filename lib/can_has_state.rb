require 'active_support'
require 'active_model'

%w(definition dirty_helper machine).each do |f|
  require "can_has_state/#{f}"
end

require 'can_has_state/railtie' if defined?(Rails)
