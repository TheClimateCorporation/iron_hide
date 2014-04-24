module IronHide
  DEFAULT = false
  class << self

    # @raise [IronHide::AuthorizationError] if authorization fails
    # @return [true] if authorization succeeds
    #
    def authorize!(user, action, resource)
      unless can?(user, action, resource)
        raise AuthorizationError
      end
      true
    end

    # @return [Boolean]
    # @param user [Object]
    # @param action [Symbol, String]
    # @param resource [Object]
    # @see IronHide::Rule::allow?
    #
    def can?(user, action, resource)
      Rule.allow?(user, action.to_s, resource)
    end

    # @return [IronHide::Storage]
    def storage
      @storage ||= IronHide::Storage.new(configuration.adapter)
    end

    attr_reader :configuration

    # @yield [IronHide::Configuration]
    def config
      yield configuration
    end

    def configuration
      @configuration ||= IronHide::Configuration.new
    end

    alias_method :configure, :config

    # Resets storage
    # Useful primarily for testing
    #
    # @return [void]
    def reset
      @storage = nil
    end

    # Delegates all logging to the logger configured in the configuration
    # object.
    def logger
      configuration.logger
    end
  end
end

require "iron_hide/version"
require 'iron_hide/errors'
require 'iron_hide/rule'
require 'iron_hide/condition'
require 'iron_hide/storage'
require 'iron_hide/configuration'
