require "bundler/gem_tasks"
require 'rspec/core/rake_task'
require 'rake/version_task'
require 'rdoc/task'

Rake::VersionTask.new

desc 'Run all specs'
RSpec::Core::RakeTask.new(:spec)

task default: :spec
task test: :spec

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.main = 'README'
  rdoc.title = " dockit #{Version.current}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Generate Documentation"
task doc: :rdoc

task :docker do
  system 'docker build -t dockit .'
end
