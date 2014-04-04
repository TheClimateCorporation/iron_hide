# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'iron_hide/version'

Gem::Specification.new do |spec|
  spec.name          = "iron_hide"
  spec.version       = IronHide::VERSION
  spec.authors       = ["Alan Cohen"]
  spec.email         = ["acohen@climate.com"]
  spec.description   = %q{A Ruby authorization library}
  spec.summary       = %q{Describe your authorization rules with JSON}
  spec.homepage      = "http://github.com/TheClimateCorporation/iron_hide"
  spec.license       = "MIT"

  spec.files         = Dir['lib/**/*.rb']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "multi_json"
  spec.add_runtime_dependency "json_minify", "~> 0.2"

  spec.add_development_dependency "bundler", "~> 1"
  spec.add_development_dependency "rake", "~> 10"
  spec.add_development_dependency "rspec", "~> 2"
  spec.add_development_dependency "yard", "~> 0"
  spec.add_development_dependency "pry"
end
