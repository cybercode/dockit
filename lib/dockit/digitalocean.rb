# This class allows for basic deployment to a digitalocean docker droplet
# via ssh (without exposing tcp access to the docker service.)
require 'droplet_kit'

class DO < Thor
  USERNAME = 'root'.freeze
  REMOTE_CMDS = %w[start push create].freeze

  def self.remote_required?(extra_cmds=[])
    ARGV[0] == 'do' && (
      REMOTE_CMDS.include?(ARGV[1]) || extra_cmds.include?(ARGV[1]))
  end

  class_option :remote, type: :string, desc: 'remote droplet address',
               required: remote_required?, aliases: ['r']
  class_option :user, type: :string, desc: 'remote user',
               default: USERNAME, aliases: ['u']
  class_option :token, type: :string,
               desc: 'token filename relative to "~/.digitalocean"',
               default: 'token'

  desc 'create', 'create droplet REMOTE'
  option :image,  type: :string, desc: 'slug for image',     default: 'docker'
  option :size,   type: :string, desc: 'size for droplet',   default: '1gb'
  option :region, type: :string, desc: 'region for droplet', default: 'nyc3'
  def create
    if find(options.remote)
      say  "Droplet #{options.remote} exists. Please destroy it first.", :red
      exit 1
    end
    say "creating droplet: #{options.remote}"
    d = client.droplets.create(DropletKit::Droplet.new(
                            name: options.remote,
                            region: options.region,
                            size: options[:size],
                            image: options[:image],
                            ssh_keys: client.ssh_keys.all.collect(&:id)))
    say [d.id, d.status, d.name].join(' ')
  end

  desc 'available', 'list available docker images'
  option :all, type: :boolean, desc: 'list ALL available images', aliases: ['a']
  def available
    f = '%-20.20s %-25.25s %s'
    say format(f, 'slug', 'name', 'regions')
    say format(f, '_' * 20, '_' * 25, '_' * 30)

    say(
      client.images.all.select do |i|
        i.slug && options.all || i.name =~ /^Docker/
      end.map do |i|
        format(f, i.slug, i.name, i.regions.join(','))
      end.sort.join("\n")
    )
  end

  desc 'list', 'list droplets'
  def list
    l = client.droplets.all.collect do |d|
      [d.id, d.name, d.status, d.networks[:v4].first.ip_address]
    end
    l.unshift %w[id name status ip]
    print_table l
  end

  desc 'destroy', 'destroy REMOTE droplet'
  option :force, type: :boolean, desc: "don't prompt"
  def destroy
    force = options[:force]
    say "Destroying droplet: #{options.remote}", force ? :red : nil
    if force || yes?("Are you sure?", :red)
      client.droplets.delete(id: find(options.remote).id)
    else
      say "#{options.remote} not destroyed", :red
    end
  end

  desc 'push [SERVICES]', 'push service(s) to digitalocean (default all)'
  option :backup, type: :boolean, desc: "Backup (tag) current version before push",
         aliases: ['b']
  option :tag, type: :string, desc: "tag name for backup", default: 'last'
  def push(*args)
    args = dockit.services.keys if args.empty?
    say "Pushing to #{options.remote} as #{options.user}", :green
    say "Processing images for #{args}"
    args.each do |k|
      s = service(k)
      unless s.image
        say ". #{k}: No image!", :red
        next
      end
      name    = s.config.get(:build, :t)
      unless name.present?
        say ". #{k}: not a local build", :red
        next
      end
      id      = s.image.id
      msg     =  "#{k}(#{id[0..11]}[#{name}]):"
      if ssh(options.remote, options.user,
             "docker images --no-trunc | grep #{id} > /dev/null")
        say ". #{msg} exists"
      else
        if options.backup
          tag = "#{k}:#{options.tag}"
          say "#{msg} tagging as #{tag}"
          ssh(options.remote, options.user, "docker tag #{name} #{tag}")
        end
        say "#{msg} pushing"
        ssh(options.remote, options.user, 'docker load', "docker save #{name}")
      end
    end
  end

  desc 'start [SERVICE]', 'start a container for SERVICE on remote server'
  option :vars, type: :hash,
         desc: 'extra environment variables not defined in Dockit.yaml'
  def start(name)
    s     = service(name)
    name  = s.name
    links = config(s, :run,    :Links, 'l')
    binds = config(s, :run,    :Binds, 'v')

    env   = config(s, :create, :Env,   'e')
    env   << (options[:vars]||{}).collect { |k,v| ['-e', "#{k}='#{v}'"]}
    env   << ['-e', "ENV='#{options.env}'"]

    cmd = ['docker', 'run', env, links, binds].join(' ')
    ssh(options.remote, options.user, cmd)
  end

  private
  def ssh(host, user, cmd, src=nil)
    src << '|' if src
    system("#{src}ssh #{user}@#{host} #{cmd}")
  end

  def client
    @client ||= DropletKit::Client.new(
      access_token: File.read(File.join(Dir.home, '.digitalocean', options.token)))
  end

  def find(hostname)
    client.droplets.all.find do |d|
      d.name == hostname
    end
  end

  def dockit
    @dockit ||= Dockit::Env.new
  end

  def service(name)
    Dockit::Service.new(
      service_file(name),
      locals: {env: options.env ? "-#{options.env}" : ''}.merge(options[:locals]||{}))
  end

  def service_file(name)
    file = dockit.services[name]
    unless file
      say "Service '#{name}' does not exist!", :red
      exit 1
    end
    file
  end

  def config(service, phase, key, flag)
    (service.config.get(phase, key)||[]).collect { |v| ["-#{flag}", "'#{v}'"] }
  end
end
