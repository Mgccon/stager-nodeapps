require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
end

require File.join('bundler', 'setup')
require 'rspec'
require 'apcera-stager-api'
