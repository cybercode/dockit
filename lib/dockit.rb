require 'docker'
require 'yaml'
require 'pathname'
require 'version'

require 'dockit/config'
require 'dockit/service'
require 'dockit/image'
require 'dockit/container'
require 'dockit/volume'

module Dockit
  is_versioned

  class Log
    def debug(msg)
      $stderr.puts "DEBUG: " + msg.join(' ')
    end

    def self.print_chunk(chunk)
      begin
        chunk = JSON.parse(chunk)
      rescue Docker::Error::UnexpectedResponseError => e
        $stderr.puts "Response parse error:", e.message, chunk
      end

      progress = chunk['progress']
      id = progress ? '' : chunk['id']
      $stdout.puts(
        if chunk['errorDetail']
          'ERROR: ' +  chunk['errorDetail']['message']
        elsif chunk['stream']
          chunk['stream']
        else
          [chunk['status'], id, progress, progress ? "\r" : "\n"].join(' ')
        end
      )
    end
  end

  # This class encapsulates the environment used in the Dockit cli.
  # The class has three main attributes:
  #
  # root ::
  #  The (cached) root of the project.
  # modules ::
  #  The "modules", a map of +Dockit.rb+ files by directory name
  # services ::
  #  The "services",  a map of +Dockit.yaml+ files, by directory name
  class Env
    BASENAME = 'Dockit'.freeze
    attr_reader :services
    attr_reader :modules

    ##
    # Initialize services and modules in the project.
    # depth [Integer] :: How deep to recurse looking for modules/services
    # debug [Boolean] :: Log +docker-api+ calls.
    def initialize(depth: 2, debug: false)
      @root = nil
      @modules  = find_subcommands(depth)
      @services = find_services(depth)

      Docker.logger = Dockit::Log.new if debug
    end

    ##
    # The (cached) root of the project
    # Returns [String] :: The absolute path of the project root.
    def root
      return @root if @root
      @root = dir = Dir.pwd
      begin
        dir = File.dirname(dir)
        return @root = dir if File.exist?(File.join(dir, "#{BASENAME}.rb"))
      end while dir != '/'

      @root
    end

    private
    def find_services(depth)
      find_relative(depth, 'yaml')
    end

    def find_subcommands(depth)
      find_relative(depth, 'rb')
    end

    def find_relative(depth, ext)
      result = {}
      (0..depth).each do |i|
        pat = File.join(root, ['*'] * i, "#{BASENAME}.#{ext}")
        Pathname.glob(pat).inject(result) do |memo, path|
          name       = path.dirname.relative_path_from(Pathname.new(root)).to_s
          name       = 'all' if name == '.'
          memo[name] = path.to_s

          memo
        end
      end
      result
    end
  end
end
