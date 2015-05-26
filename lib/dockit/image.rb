module Dockit
  class Image
    attr_reader :image

    class << self
      def list(all: false, filters: nil)
        Docker::Image.all(all: all, filters: JSON.dump(filters))
      end

      def create(config)
        unless config
          STDERR.puts "No build target configured"
          return
        end
        repos = config['t']
        puts  "Building #{repos}"
        image = Docker::Image.build_from_dir('.', config) do |chunk|
          begin
            chunk = JSON.parse(chunk)
            progress = chunk['progress']
            id = progress ? '' : chunk['id']
            print chunk['stream'] ? chunk['stream'] :
                    [chunk['status'], id, progress, progress ? "\r" : "\n"].join(' ')
          rescue
            puts chunk
          end
        end

        image
      end

      def get(name)
        Docker::Image.get(name)
      end

      def clean(force: false)
        list(
          all: force,
          filters: force ? nil : {dangling: ['true']}
        ).each do |image|
          puts "  #{image.id}"
          image.remove(force: true)
        end
      end
    end
  end
end
