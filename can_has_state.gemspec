$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "can_has_state/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "can_has_state"
  s.version     = CanHasState::VERSION
  s.authors     = ["t.morgan"]
  s.email       = ["tm@iprog.com"]
  s.homepage    = "http://iprog.com/projects"
  s.summary     = "Super simple state machine for ActiveModel"
  s.description = "can_has_state is a simplified state machine gem. It relies on ActiveModel and
  should be compatible with any ActiveModel-compatible persistence layer."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "activemodel", "~> 3.2.8"
  s.add_dependency "activesupport", "~> 3.2.8"

  s.add_development_dependency "sqlite3"
end
