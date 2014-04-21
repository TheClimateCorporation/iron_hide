require 'iron_hide/memoize'

module IronHide
  class Rule
    ALLOW     = 'allow'.freeze
    DENY      = 'deny'.freeze

    attr_reader :description, :effect, :conditions, :user, :resource, :cache

    def initialize(user, resource, params = {}, cache = NullCache.new)
      @user        = user
      @resource    = resource
      @description = params['description']
      @effect      = params.fetch('effect', DENY) # Default DENY
      @conditions  = Array(params['conditions']).map { |c| Condition.new(c, cache) }
    end

    # Returns all applicable rules matching on resource and action
    #
    # @param user [Object]
    # @param action [String]
    # @param resource [Object]
    # @return [Array<IronHide::Rule>]
    def self.find(user, action, resource)
      cache       = IronHide.configuration.memoizer.new
      ns_resource = "#{IronHide.configuration.namespace}::#{resource.class.name}"
      storage.where(resource: ns_resource, action: action).map do |json|
        new(user, resource, json, cache)
      end
    end

    # NOTE: If any Rule is an explicit DENY, then an allow cannot override the Rule
    #       If any Rule is explicit ALLOW, and there is no explicit DENY, then ALLOW
    #       If no Rules match, then DENY
    #
    # @return [Boolean]
    # @param user [Object]
    # @param action [String]
    # @param resource [String]
    #
    def self.allow?(user, action, resource)
      find(user, action, resource).inject(false) do |rval, rule|
        # For an explicit DENY, stop evaluating, and return false
        rval = false and break if rule.explicit_deny?

        # For an explicit ALLOW, true
        rval = true if rule.allow?

        rval
      end
    end

    # An abstraction over the storage of the rules
    # @see IronHide::Storage
    # @return [IronHide::Storage]
    def self.storage
      IronHide.storage
    end

    # @return [Boolean]
    def allow?
      effect == ALLOW && conditions.all? { |c| c.met?(user,resource) }
    end

    # @return [Boolean]
    def explicit_deny?
      effect == DENY && conditions.all? { |c| c.met?(user,resource) }
    end

    alias_method :deny?, :explicit_deny?
  end
end
