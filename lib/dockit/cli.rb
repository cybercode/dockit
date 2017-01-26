# coding: utf-8
require 'io/console'
require 'thor'
require 'dockit'

GIT_BRANCH=`git symbolic-ref --short HEAD 2>/dev/null`.chomp

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
      invoke cmd, [], options.merge(opts)
      instance_variable_get('@_invocations')[Default].slice!(-1)
    end

    # export git repository before running default command
    def invoke_git(service)
      invoke_default service, cmd: 'git-build'
    end

    def project_root
      shell.base.project_root
    end

    def directory
      @directory ||= shell.base.module_directory(self.class)
    end

    def in_directory
      Dir.chdir(directory) do
        yield
      end
    end
  end
end

class Default < Thor
  DOCKIT_FILE = './Dockit.yaml'.freeze
  @@root_echoed = false

  class_option :host, type: :string, desc: 'override DOCKER_HOST env variable',
               default: ENV['DOCKER_HOST'], aliases: ['H']
  class_option :debug, type: :boolean, desc: "Log docker-api calls"
  class_option :verbose, type: :boolean, aliases: ['v']
  class_option :env, type: :string, desc: 'e.g., "test", "staging"', aliases: ['e']
  class_option :locals, type: :hash, aliases: ['l'],
               banner: "key:value [key:value ...]",
               desc: "variables to pass to yaml file."
  class_option :timeout, type: :numeric, desc: 'Timeout for excon', default: 180

  def initialize(*args)
    super
    ENV['DOCKER_HOST'] = options.host

    # passed to Excon, default is 60sec,
    Docker.options[:read_timeout] = options.timeout

    unless @@root_echoed
      say "Project root: #{project_root}", :red
      @@root_echoed=true
    end
  end

  no_commands do
    def _list(what)
      puts what.to_s.capitalize, dockit.send(what).keys.collect {|s| "  #{s}"}
    end

    def module_directory(klass)
      File.dirname(dockit.modules[klass.to_s.downcase])
    end

    def project_root
      dockit.root
    end
  end

  def help(*args)
    super
    if args.count < 1
      say "Run 'dockit list' to see the complete list of SERVICEs."
      say "Run 'dockit help COMMAND' to see command specific options."
    end
  end

  desc "version", "Print version"
  def version
    say "Dockit version #{Dockit::VERSION}"
  end
  map %w[--version -V] => :version

  desc "list", "List available services"
  def list
    _list :modules
    _list :services
  end

  # "run" is a reserved word in thor...
  desc 'start [SERVICE] [CMD]', 'run a service, optionally override "Cmd"'
  option :transient, type: :boolean, desc: 'remove container after run'
  def start(service=nil, *cmd)
    opts = options.merge(create: { tty: options[:transient] })
    opts[:create][:Cmd] = cmd unless cmd.empty?
    exec(service) do |s|
      s.start(opts)
    end
  end

  desc 'sh [SERVICE] [CMD]', 'run an interactive command (default "sh -l")'
  def sh(service=nil, *cmd)
    exec(service) do |s|
      cmd  = %w[sh -l] if cmd.empty?
      name = ['exec', cmd.first, s.name].join('-')

      # in case image has an entrypoint, use the cmd as the entrypoint
      (entrypoint, *cmd) = cmd
      say "Starting #{name} with #{entrypoint} #{cmd}", :green
      s.start(
        transient: true,
        verbose: options.verbose,
        create: {
          Entrypoint: [entrypoint],
          Cmd: cmd,
          name: name,
          Tty: true,
          AttachStdin: true,
          AttachStdout: true,
          AttachStderr: true,
          OpenStdin: true,
          StdinOnce: true,
        })
    end
  end

  desc "cleanup", "Remove unused containers and images"
  option :images    , type: :boolean, default: true , desc: "remove danging images"
  option :containers, type: :boolean, default: true , desc: "remove exited containers"
  option :volumes   , type: :boolean, default: true , desc: 'remove dangling volumes'
  option 'force-containers', type: :boolean, default: false,
         desc: 'stop and remove all containers', aliases: %[f]
  option 'except-containers', type: :array,
         desc: "container names to leave if 'force-containers' true", aliases: %[C]
  option 'force-images', type: :boolean, default: false, desc: 'remove ALL volumes'
  option 'except-images', type: :array,
         desc: "image tags (name:version) to leave if 'force-images' true", aliases: %[I]
  def cleanup
    Dockit::Container.clean(
      force: options['force-containers'], except: options['except-containers']
    ) if options[:containers]

    Dockit::Image.clean(
      force: options['force-images'], except: options['except-images']
    ) if options[:images]

    if options[:volumes] && Docker.version['ApiVersion'].to_f >= 1.21
      Dockit::Volume.clean
    else
      say "Volumes not supported on API versions < 1.21", :red
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

  desc 'build [SERVICE]', "Build image from current directory or service name"
  def build(service=nil)
    exec(service) do |s|
      s.build()
    end
  end

  desc 'git-build', 'build from git repository'
  option :branch, desc: '<tree-ish> git reference', default: GIT_BRANCH
  option :package, type: :boolean, desc: 'update package config export'
  option :tag, type: :boolean,
         desc: 'create local tag file ".branch" with branch name'
  long_desc <<-LONGDESC
     Dockit.yaml keys used:
     \x5 repos_path: optional treeish path
     \x5 repos: repository location
     \x5 package: optional

    `dockit git-build` will export {branch}:repos_path from the
     repository location specified in the :repos key to 'repos.tar.gz'

     The '--package' option will export the files in the :package key in
     Dockit.yaml separately to 'package.tar.gz'. This is docker best practice
     for building rails apps, and works equally well for nodejs.

     *Breaking change (2.0)* ~branch~ now defaults to the *current* local
      branch, not ~master~.
  LONGDESC

  def git_build(service=nil)
    exec(service) do |s|
      unless repos = s.config.get(:repos)
        say "'repos' not defined in config file. Exiting…", :red
        exit 1
      end
      path    = s.config.get(:repos_path)
      treeish = unless path.nil? || path.empty?
                  "#{options.branch}:#{path}"
                else
                  options.branch
                end
      say "Exporting in #{Dir.pwd}", :green
      say "<- #{repos} #{treeish}", :green

      if options.package
        unless packages = s.config.get(:package)
          say "'packages' not defined in config file. Exiting…", :red
          exit 1
        end

        say '-> package.tar.gz', :green
        export(repos, treeish, 'package.tar.gz', packages)
      end

      say '-> repos.tar.gz', :green
      export(repos, treeish, 'repos.tar.gz')

      say "Creating '.branch' tag file (#{options.branch})", :blue
      File.write('.branch', "#{options.branch}\n")

      s.build
    end
  end

  private
  GIT_CMD = 'git archive -o %s --format tar.gz --remote %s %s %s'.freeze
  def export(repos, branch, archive, args='')
    if repos =~ /\A\./
      repos = File.absolute_path(repos) # git 2.11.0 unhappy w/ '../..'
    end

    cmd = GIT_CMD % [archive, repos, branch, args]
    say "#{cmd}\n", :blue if options.debug

    unless system(cmd)
      say "Export error", :red
      exit 1
    end
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
rescue LoadError => e
  STDERR.puts "* No DigitalOcean support: #{e.message}"
end

# it would be nice to do this in the initialization method of the Default
# class above, but it hasn't been instantiated yet when invoking a subcommand.
Dockit::Env.new.modules.each do |k, v|
  begin
    require v
    Default.desc k, "#{k} submodule, see 'help #{k}'"
    Default.subcommand k, Module.const_get(k.capitalize)
  rescue NameError => e
    STDERR.puts "Can't load #{v}: #{e}"
  end
end
