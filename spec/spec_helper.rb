$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'simplecov'
if ENV['COVERAGE']
  puts 'Generating coverage report'
  SimpleCov.start
end

require 'dockit'
