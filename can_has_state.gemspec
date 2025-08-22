$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "can_has_state/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "can_has_state"
  spec.version     = CanHasState::VERSION
  spec.authors     = ["thomas morgan"]
  spec.email       = ["tm@iprog.com"]
  spec.homepage    = "https://github.com/zarqman/can_has_state"
  spec.summary     = "Super simple state machine for ActiveModel"
  spec.description = "can_has_state is a simplified state machine gem. It relies on ActiveModel and should be compatible with any ActiveModel-compatible persistence layer."
  spec.license     = 'MIT'

  spec.files = Dir["{app,config,db,lib}/**/*"] + ["LICENSE.txt", "Rakefile", "README.md"]
  spec.test_files = Dir["test/**/*"]

  spec.required_ruby_version = '>= 2.7'

  spec.add_dependency "activemodel", ">= 7.0"

  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'rake'
end
