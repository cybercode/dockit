module Dockit
  class Volume
    attr_reader :volume

    class << self
      def list(dangling: false)
        fetch(dangling: dangling)
      end

      # can't remove non-dangling containers, so don't bother
      # with "force" argument
      def clean
        puts "Volumes..."
        (list(dangling: true)||[]).each do |volume|
          name = volume['Name']
          puts "  #{name}"
          delete(name)
        end
      end

      def delete(name)
        Docker.connection.delete("/volumes/#{name}")
      end


      private
      def fetch(path='', dangling: false)
        Docker::Util.parse_json(
          Docker.connection.get(
          "/volumes#{path}", filters: JSON.dump({dangling: [dangling.to_s]}))
        )['Volumes']
      end
    end
  end
end
