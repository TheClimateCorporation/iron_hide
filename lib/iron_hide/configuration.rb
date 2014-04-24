require 'logger'

module IronHide
  class Configuration

    attr_accessor :adapter, :namespace, :json, :memoize, :logger

    def initialize
      @adapter   = :file
      @namespace = 'com::IronHide'
      @memoize   = true
      @logger =  Logger.new($stdout).tap do |log|
          log.progname = 'ironhide'
          log.level = Logger::WARN
      end
    end

    def memoizer
      memoize ? SimpleCache : NullCache
    end

    # Extend configuration variables
    #
    # @param config_hash [Hash]
    #
    # @example
    #   IronHide.configuration.add_configuration(couchdb_server: 'http://127.0.0.1:5984')
    #   IronHide.configuration.couchdb_server)
    #   #=> 'http://127.0.0.1:5984'
    #
    #   IronHide.configuration.couchdb_server = 'other'
    #   #=> 'other'
    #
    def add_configuration(config_hash)
      config_hash.each do |key, val|
        instance_eval { instance_variable_set("@#{key}",val) }
        self.class.instance_eval { attr_accessor key }
      end
    end
  end
end
