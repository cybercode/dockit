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
        begin
          image = Docker::Image.build_from_dir('.', config) do |chunk|
            Dockit::Log.print_chunk(chunk)
          end
        rescue Docker::Error::TimeoutError => e
          $stderr.puts '* Read timeout, try again with a larger "--timeout"'
          exit 1
        rescue Docker::Error::UnexpectedResponseError => e
          $stderr.puts 'Build error, exiting.'
          exit 1
        end

        image
      end

      def get(name)
        Docker::Image.get(name)
      end

      def clean(force: false, except: [])
        except ||= []
        puts "Images..."
        list(
          all: force,
          filters: force ? nil : {dangling: ['true']}
        ).each do |image|
          names = image.info["RepoTags"]||[]
          puts "  #{image.id}"
          if (names & except).count > 0
            puts "  ... skipping #{names}"
            next
          end

          image.remove(force: true)
        end
      end
    end
  end
end
