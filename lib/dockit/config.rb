# Parse a dockit config file.
# The dockit configuration file should contain the necessary options for
# passing to the appropriate Docker api methods for image creation (build) or
# container creation (running.)
# The file is passed through ERB before YAML loading.
require 'erb'
require 'dotenv'

module Dockit
  class Config
    ENVFILE='.env'
    # Instantiate and parse the file.
    #
    # file   - dockit yaml file
    # locals - hash of local variables
    def initialize(file, locals={})
      root = Dockit::Env.new.root
      Dotenv.load(File.join(root, ENVFILE))
      locals['root'] ||= root

      begin
        @config = YAML::load(ERB.new(File.read(file)).result(bindings(locals)))
      rescue NameError => e
        error(e)
      rescue ArgumentError => e
        error(e)
      end
    end
    # Public: Return the configuration hash for a given phase
    # The Dockit.yaml file should have top-level entries for (at least)
    # `build` and `run`
    #
    # If a key is specified, return it's value from the hash
    def get(name, key=nil)
      phase = @config[name.to_s]
      return phase unless key && phase

      phase[key.to_s]
    end

    private
    # Generate bindings object for locals to pass to erb
    #
    # locals - hash converted to local variables
    #
    # Returns binding object
    def bindings(locals)
      b  = binding
      locals.each do |k,v|
        b.local_variable_set(k, v)
      end

      return b
    end

    def error(e)
      abort [e.message.capitalize,
             "Did you forget '--locals key:value'?"].join("\n")
    end
  end
end
