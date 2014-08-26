# Were running tests?
RSPEC_RUNNING = true

require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
end

require File.join('bundler', 'setup')
require 'rspec'
require 'vcr'
require 'continuum-stager-api'

root_path = File.join(Gem::Specification.find_by_name("continuum-stager-api").gem_dir, "spec")

VCR.configure do |c|
  c.cassette_library_dir = File.join(root_path, 'fixtures/cassettes')
  c.hook_into :webmock
  c.default_cassette_options = { :match_requests_on => [:path], :record => :new_episodes, :erb => true, :serialize_with => :yaml }
end

RSpec.configure do |config|
  # Use color in STDOUT
  config.color_enabled = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate
end
