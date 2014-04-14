module IronHide
  class Storage
    # @api private
    class FileAdapter
      attr_reader :rules

      def initialize
        json = Array(IronHide.configuration.json).each_with_object([]) do |file, ary|
          ary.concat(MultiJson.load(File.open(file).read, minify: true))
        end
        @rules = unfold(json)
      rescue MultiJson::ParseError => e
        raise IronHideError, "#{e.cause}: #{e.data}"
      rescue => e
        raise IronHideError, "Invalid or missing JSON file: #{e.to_s}"
      end

      def where(opts = {})
        self[opts[:resource]][opts[:action]]
      end

      # Unfold the JSON definitions of the rules into a Hash with this structure:
      # {
      #   "com::test::TestResource" => {
      #     "action" => [
      #       { ... }, { ... }, { ... }
      #     ]
      #   }
      # }
      #
      # @param json [Array<Hash>]
      # @return [Hash]
      def unfold(json)
        json.inject(hash_of_hashes) do |rules, json_rule|
          resource, actions = json_rule["resource"], json_rule["action"]
          actions.each { |act| rules[resource][act] << json_rule }
          rules
        end
      end

      private

      # Return a Hash with default value that is a Hash with default value of Array
      # @return [Hash<Hash, Array>]
      def hash_of_hashes
        Hash.new { |h1,k1|
          h1[k1] = Hash.new { |h,k| h[k] = [] }
        }
      end

      # Implements an interface that makes selecting rules look like a Hash:
      # @example
      #   {
      #     'com::test::TestResource' => {
      #       'read' => [],
      #       ...
      #     }
      #   }
      #  adapter['com::test::TestResource']['read']
      #  #=> [Array<Hash>]
      #
      # @param [Symbol] val
      # @return [Array<Hash>] array of canonical JSON representation of rules
      def [](val)
        rules[val]
      end
    end
  end
end
