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
    BASENAME = 'Dockit'.freeze

    attr_reader :services
    attr_reader :modules
    attr_reader :depth

    def initialize(depth: 2, debug: false)
      @modules  = find_subcommands(depth)
      @services = find_services(depth)

      Docker.logger = Dockit:: Log.new if debug
    end

    def root
      return @root if @root
      @root = dir = Dir.pwd
      begin
        dir = File.dirname(dir)
        return @root = dir if File.exists?(File.join(dir, "#{BASENAME}.rb"))
      end while dir != '/'

      @root
    end

    def find_services(depth)
      find_relative(depth, 'yaml')
    end

    def find_subcommands(depth)
      fix_root_module(find_relative(depth, 'rb'))
    end

    private
    def find_relative(depth, ext)
      memo = {}
      (0..depth).each do |i|
        pat = File.join(root, ['*'] * i, "#{BASENAME}.#{ext}")
        Pathname.glob(pat).inject(memo) do |memo, path|
          name       = path.dirname.relative_path_from(Pathname.new(root)).to_s
          name       = path.dirname.basename.to_s if name == '.'
          memo[name] = path.to_s

          memo
        end
      end
      memo
    end

    def fix_root_module(modules)
      if File.exists?(File.join(root, 'Dockit.rb'))
        modules['all'] = modules.delete(File.basename(root))
      end
      modules
    end
  end
end
