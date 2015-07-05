module Dockit
  class Service
    attr_reader :config
    attr_reader :image

    def initialize(file="./Dockit.yaml", locals: {})
      @config = Dockit::Config.new(file, locals)

      # get the image if it is specified and already exists
      if name = config.get(:create, :Image) || config.get(:build, :t)
        begin
          @image = Dockit::Image.get(name)
        rescue Docker::Error::NotFoundError
        end
      end
    end

    def build
      @image = Dockit::Image.create(config.get(:build))
    end

    def start(options)
      opts = merge_config(:create, stringify(options[:create]))
      unless image || opts['Image']
        raise "No runnable image found or specified!"
      end

      opts['Image'] ||= image.id if image
      opts['name']  ||= config.get(:build, :t)

      run = merge_config(:run, stringify(options[:run]))

      if options[:verbose]
        cmd = [(opts['Entrypoint']||[]), ((opts['Cmd'] || %w[default]))].flatten
        puts " * %s (%s)" % [ opts['name'] || 'unnamed', cmd.join(' ') ]

        puts " * #{run}" if run.length > 0
      end

      Dockit::Container.new(opts).start(
        run, verbose: options[:verbose], transient: options[:transient])
    end

    def push(registry, tag=nil, force=false)
      raise "No image found!" unless image

      image.tag(repo: "#{registry}/#{config.get(:build, 't')}", force: force)
      STDOUT.sync = true
      image.push(tag: tag) do |chunk|
        chunk = JSON.parse(chunk)
        progress = chunk['progress']
        id = progress ? '' : "#{chunk['id']} "
        print chunk['status'], ' ', id, progress, progress ? "\r" : "\n"
      end
    end

    def pull(registry, tag=nil, force=false)
      unless repo = config.get(:build, 't')
        STDERR.puts "No such locally built image"
        exit 1
      end

      name = "#{registry}/#{repo}"
      image = Docker::Image.create(
        fromImage: name) do |chunk|
        chunk = JSON.parse(chunk)
        progress = chunk['progress']
        id = progress ? '' : chunk['id']
        print chunk['stream'] ? chunk['stream'] :
                [chunk['status'], id, progress, progress ? "\r" : "\n"].join(' ')
      end
      puts "Tagging #{name} as #{repo}:#{tag||'latest'}"
      image.tag(repo: repo, tag: tag, force: force)
    end

    def id
      image.id
    end

    private
    def merge_config(key, opts)
      (config.get(key) || {}).merge(opts||{})
    end

    def stringify(hash)
      return nil unless hash
      Hash[hash.map {|k,v| [k.to_s, v]}]
    end
  end
end
