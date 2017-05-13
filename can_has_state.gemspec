$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "can_has_state/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "can_has_state"
  s.version     = CanHasState::VERSION
  s.authors     = ["thomas morgan"]
  s.email       = ["tm@iprog.com"]
  s.homepage    = "https://github.com/zarqman/can_has_state"
  s.summary     = "Super simple state machine for ActiveModel"
  s.description = "can_has_state is a simplified state machine gem. It relies on ActiveModel and
  should be compatible with any ActiveModel-compatible persistence layer."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "activemodel", ">= 4", "< 5.1"
  s.add_dependency "activesupport", ">= 4", "< 5.1"

  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-reporters'
end
