module Dockit
  class Container
    attr_reader :container

    class << self
      def list(all: false, filters: nil)
        Docker::Container.all(all: all, filters: JSON.dump(filters))
      end

      def clean(force: false)
        list(
          all: force,
          filters: force ? nil : {status: [:exited]}
        ).each do |container|
          puts "  #{container.id}"
          container.delete(force: true, v: force)
        end
      end

      def find(name: nil, id: nil)
        unless name || id
          STDERR.puts "Must specify name or id"
          exit -1
        end
        list().find do |container|
          name && container.info['Names'].include?(name) ||
            id && container.id == id
        end

      end
    end

    def initialize(options)
      @tty = options[:Tty]
      @container = Docker::Container.create(options)
    end

    def start(options={}, verbose: true, transient: false)
      container.start!(options)
      if transient
        if @tty
          trap("INT") {}
        end
        container.attach(tty: @tty, stdin: @tty ? STDIN : nil) do |*args|
          if @tty then
            print args[0]
          else
            msg(*args)
          end
        end
        destroy
      end
    end

    def destroy
      puts "Deleting container #{container.id}"
      container.delete(force: true, v: true)
    end

    private
    def msg(stream, chunk)
      pfx = stream.to_s == 'stdout' ? 'INFO: ' : 'ERROR: '
      puts pfx +
           [chunk.sub(/^\n/,'').split("\n")]
             .flatten
             .collect(&:rstrip)
             .reject(&:empty?)
             .join("\n#{pfx}")
    end

    def binds(options)
      return unless options['Volumes']

      options['Volumes'].collect do |k, v|
        "#{Dir.pwd}/#{v}:#{k}"
      end
    end
  end
end
