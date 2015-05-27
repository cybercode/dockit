require 'thor'
require 'dockit'

class SubCommand < Thor
  no_commands do
    # invoke command against the Dockit.yaml for the given service.
    def invoke_default(service=nil, cmd: nil, opts: {})
      service  ||= self.class.to_s.downcase
      cmd ||= current_command_chain[-1]
      cmd = "default:#{cmd}"
      invoke cmd, [service], options.merge(opts)
      instance_variable_get('@_invocations')[Default].slice!(-1)
    end

    # invoke the method in the Dockit.rb for the given service.
    def invoke_service(service, cmd: nil, opts: {})
      cmd ||= current_command_chain[-1]
      cmd = "#{service}:#{cmd}"

      say "Invoking #{cmd}"
      invoke cmd, options.merge(opts)
      instance_variable_get('@_invocations')[Default].slice!(-1)
    end
  end
end

class Default < Thor
  DOCKIT_FILE = './Dockit.yaml'.freeze

  class_option :host, type: :string, desc: 'override DOCKER_HOST env variable',
               default: ENV['DOCKER_HOST'], aliases: ['H']
  class_option :debug, type: :boolean, desc: "Log docker-api calls"
  class_option :verbose, type: :boolean, aliases: ['v']
  class_option :env, type: :string, desc: 'e.g., "test", "staging"', aliases: ['e']
  class_option :locals, type: :hash, aliases: ['l'],
               banner: "key:value [key:value ...]",
               desc: "variables to pass to yaml file."

  def initialize(*args)
    super
    ENV['DOCKER_HOST'] = options.host
    puts "Running from #{dockit.root}"
  end

  no_commands do
    def _list(what)
      puts what.to_s.capitalize, dockit.send(what).keys.collect {|s| "  #{s}"}
    end
  end

  def help(*args)
    super
    if args.count < 1
      say "Run 'dockit list' to see the complete list of SERVICEs."
      say "Run 'dockit help COMMAND' to see command specific options."
    end
  end

  desc "list", "List available services"
  def list
    _list :modules
    _list :services
  end

  desc 'build [SERVICE]', "Build image from current directory or service name"
  def build(service=nil)
    exec(service) do |s|
      s.build()
    end
  end

  # "run" is a reserved word in thor...
  desc 'start [SERVICE]', 'run a service'
  option :transient, type: :boolean, desc: 'remove container after run'
  def start(service=nil)
    exec(service) do |s|
      s.start(options)
    end
  end

  desc 'sh [SERVICE]', 'run an interactive command'
  option :cmd, desc: "run command instead of shell", default: 'bash -l',
         aliases: ['c']
  def sh(service=nil)
    exec(service) do |s|
      cmd = %w[bash -l]
      s.start(
        transient: true,
        create: {
          Cmd: options.cmd.split(' '),
          name: 'sh',
          Tty: true,
          AttachStdin: true,
          # AttachStdout: true,
          # AttachStderr: true,
          OpenStdin: true,
          StdinOnce: true,
        })
    end
  end

  desc "cleanup", "Remove unused containers and images"
  option :images     , type: :boolean, default: true, desc: "remove danging images"
  option :containers , type: :boolean, default: true, desc: "remove exited containers"
  option :force, type: :boolean, default: false, desc: "stop and remove all"
  def cleanup
    if options[:containers]
      Dockit::Container.clean(force: options[:force]) if ask_force('containers')
    end
    if options[:images]
      Dockit::Image.clean(force: options[:force]) if ask_force('images')
    end
  end

  desc 'config [SERVICE]', 'show parsed Dockit.yaml config file'
  def config(service=nil)
    exec(service) do |s|
     say s.config.instance_variable_get('@config').to_yaml
    end
  end
  desc 'push REGISTRY [SERVICE]', 'push image for SERVICE to REGSITRY'
  option :force, type: :boolean, desc: 'overwrite current lastest version'
  option :tag,  desc: 'repos tag (defaults to "latest")', aliases: ['t']
  def push(registry, service=nil)
    exec(service) do |s|
      s.push(registry, options[:tag], options[:force])
    end
  end

  desc 'pull REGISTRY [SERVICE]', 'pull image for SERVICE from REGSITRY'
  option :force, type: :boolean, desc: 'overwrite current tagged version'
  option :tag,  desc: 'repos tag (defaults to "latest")', aliases: ['t']
  def pull(registry, service=nil)
    exec(service) do |s|
      s.pull(registry, options[:tag], options[:force])
    end
  end

  private
  def ask_force(type)
    force = options[:force]
    say "Removing #{force ? 'ALL' : ''} #{type}...", force ? :red : nil

    return true ### DISABLED# unless force
    yes? '... Are you sure?'
  end

  def dockit
    @@dockit ||= Dockit::Env.new(debug: options[:debug])
  end

  def exec(service)
    file = _file(service)
    if file != DOCKIT_FILE
      say "Processing #{service}"
      # problem w/ path length for docker build, so change to local directory
      Dir.chdir(File.dirname(file))
    end

    locals = options[:locals]||{}
    env = options[:env]
    locals[:env] = env ? "-#{env}" : ""
    yield Dockit::Service.new(locals: locals)
  end

  def _file(service)
    return dockit.services[service] if service && dockit.services[service]
    return DOCKIT_FILE if File.exist?(DOCKIT_FILE)
    say "No config file in current directory", :red
    help
    exit
  end
end

# Add digital ocean support if droplet_kit is installed
begin
  require 'dockit/digitalocean'
  Default.desc 'do', 'manage docker server'
  Default.subcommand 'do', DO
rescue LoadError
end

# it would be nice to do this in the initialization method of the Default
# class above, but it hasn't been instantiated yet when invoking a subcommand.
Dockit::Env.new.modules.each do |k, v|
  require v
  Default.desc k, "#{k} submodule, see 'help #{k}'"
  Default.subcommand k, Module.const_get(k.capitalize)
end
