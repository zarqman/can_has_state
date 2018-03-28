require 'active_support'
require 'active_model'

%w(definition dirty_helper machine).each do |f|
  require "can_has_state/#{f}"
end

# require 'active_support/i18n'
I18n.load_path << File.dirname(__FILE__) + '/can_has_state/locale/en.yml'

require 'can_has_state/railtie' if defined?(Rails)
