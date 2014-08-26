# -*- encoding: utf-8 -*-
Gem::Specification.new do |gem|
  gem.add_dependency "rest-client"
  gem.add_dependency 'json'

  gem.authors       = ["Josh Ellithorpe"]
  gem.email         = ["josh@apcera.com"]
  gem.description   = %q{Continuum Stager api library}
  gem.summary       = %q{Continuum Stager api library which makes it super easy to write stagers for Apcera's Continuum.}
  gem.homepage      = "http://apcera.com"
  gem.license       = "MIT"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {spec}/*`.split("\n")
  gem.name          = "continuum-stager-api"
  gem.require_paths = ["lib"]
  gem.version       = "0.1.3"

  gem.add_development_dependency 'rspec', '~> 2.6.0'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'webmock', '1.11'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'vcr'
end
