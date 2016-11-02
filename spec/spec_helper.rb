$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
if ENV['COVERAGE']
  require 'simplecov'
  puts 'Generating coverage report'
  SimpleCov.start
end

require 'dockit'
