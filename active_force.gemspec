# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_force/version'

Gem::Specification.new do |spec|
  spec.name          = "active_force"
  spec.version       = ActiveForce::VERSION
  spec.authors       = ["Eloy Espinaco", "Pablo Oldani", "Armando Andini", "José Piccioni"]
  spec.email         = "eloyesp@gmail.com"
  spec.description   = %q{Use SalesForce as an ActiveModel}
  spec.summary       = %q{Help you implement models persisting on Sales Force within Rails using RESTForce}
  spec.homepage      = "https://github.com/Beyond-Finance/active_force#readme"
  spec.license       = "MIT"
  spec.metadata      = {
    "bug_tracker_uri"   => "https://github.com/Beyond-Finance/active_force/issues",
    "changelog_uri"     => "https://github.com/Beyond-Finance/active_force/blob/main/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/Beyond-Finance/active_force",
  }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_dependency 'activemodel', '~> 7.0'
  spec.add_dependency 'activesupport', '~> 7.0'
  spec.add_dependency 'restforce',   '>= 5'
  spec.add_development_dependency 'rake', '>= 0'
  spec.add_development_dependency 'rspec', '>= 0'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'pry', '>= 0'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-cobertura'
end
