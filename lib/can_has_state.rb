require 'active_support'
require 'active_model'

%w(definition dirty_helper machine trigger).each do |f|
  require "can_has_state/#{f}"
end

require 'active_support/i18n'
Dir[File.join(__dir__, 'can_has_state', 'locale', '*.yml')].each do |fn|
  I18n.load_path << fn
end

require 'can_has_state/railtie' if defined?(Rails)
