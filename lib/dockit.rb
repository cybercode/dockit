require 'docker'
require 'yaml'
require 'pathname'

require 'dockit/config'
require 'dockit/service'
require 'dockit/image'
require 'dockit/container'
require 'dockit/version'

module Dockit
  class Log
    def debug(msg)
      STDERR.puts "DEBUG: " + msg.join(' ')
    end
  end

  class Env
    attr_reader :services
    attr_reader :modules

    def initialize(root: nil, debug: false)
      @root         = root      # must be first!
      @modules      = find_subcommands
      @services     = find_services

      Docker.logger = Dockit:: Log.new if debug
    end

    def root
      return @root if @root
      @root = dir = Dir.pwd
      begin
        dir = File.dirname(dir)
        return @root = dir if File.exists?(File.join(dir, 'Dockit.rb'))
      end while dir != '/'

      @root
    end

    def find_services
      find_relative("**/Dockit.yaml")
    end

    def find_subcommands
      fix_root_module(find_relative('**/Dockit.rb'))
    end

    private
    def find_relative(path)
      Pathname.glob("#{root}/#{path}").inject({}) do |memo, path|
        name       = path.dirname.relative_path_from(Pathname.new(self.root)).to_s
        name       = path.dirname.basename.to_s if name == '.'
        memo[name] = path

        memo
      end
    end

    def fix_root_module(modules)
      if File.exists?(File.join(root, 'Dockit.rb'))
        modules['all'] = modules.delete(File.basename(root))
      end
      modules
    end
  end
end
