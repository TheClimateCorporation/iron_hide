module IronHide
  # @raise [IronHide::AuthorizationError] if authorization fails
  # @return [true] if authorization succeeds
  #
  def self.authorize!(user, action, resource)
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
  def self.can?(user, action, resource)
    Rule.allow?(user, action.to_s, resource)
  end

  # Specify where to load rules from. This is specified in a config file
  # @param type [:file] Specify the adapter type. Only json is supported
  # for now
  def self.adapter=(type)
    @adapter_type = type
  end

  def self.adapter
    @adapter_type
  end

  # Set the top-level namespace for the application's Rules
  #
  # @param val [String]
  # @example
  #   'com::myCompany::myProject'
  def self.namespace=(val)
    @namespace = val
  end

  # Default namespace is com::IronHide
  #
  # @return [String]
  def self.namespace
    @namespace || 'com::IronHide'
  end

  # Specify the file path for the JSON flat-file for rules
  # Only applicable if using the JSON adapter
  # @param files [String, Array<String>]
  #
  def self.json=(*files)
    @json_files = files
  end

  # @return [Array<String>]
  def self.json
    @json_files
  end

  # @return [IronHide::Storage]
  def self.storage
    @storage ||= begin
      if @adapter_type.nil?
        raise IronHideError, "Storage adapter not defined"
      end
      IronHide::Storage.new(@adapter_type)
    end
  end

  # Allow the module to be configurable from a config file
  # See: {file:README.md}
  # @yield [IronHide]
  def self.config
    yield self
  end

  # Resets internal state
  #
  # @return [void]
  def self.reset
    instance_variables.each { |i| instance_variable_set(i,nil) }
  end
end

require "iron_hide/version"
require 'iron_hide/errors'
require 'iron_hide/rule'
require 'iron_hide/condition'
require 'iron_hide/storage'
