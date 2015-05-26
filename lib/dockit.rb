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

    def root
      return @root if @root
      @root = dir = Dir.pwd
      begin
        dir = File.dirname(dir)
        return @root = dir if File.exists?(File.join(dir, 'Dockit.rb'))
      end while dir != '/'

      @root
    end

    def initialize(debug: false, root: nil)
      @modules      = find_subcommands
      @services     = find_services
      @root         = root
      Docker.logger = Dockit:: Log.new if debug
    end

    def find_services
      _find_relative("**/Dockit.yaml")
    end

    def find_subcommands
      _find_relative('**/Dockit.rb')
    end

    private
    def _find_relative(path)
      Pathname.glob("#{root}/#{path}").inject({}) do |memo, path|
        name       = path.dirname.relative_path_from(Pathname.new(self.root)).to_s
        name       = path.dirname.basename.to_s if name == '.'
        memo[name] = path

        memo
      end
    end
  end
end
