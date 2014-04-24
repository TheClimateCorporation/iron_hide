require 'iron_hide/memoize'
require 'pry'

module IronHide
  class Rule
    ALLOW     = 'allow'.freeze
    DENY      = 'deny'.freeze

    attr_reader :description, :effect, :conditions, :user, :resource, :cache,
      :uuid

    def initialize(user, resource, params = {}, cache = NullCache.new)
      @user        = user
      @resource    = resource
      @description = params['description']
      @effect      = params.fetch('effect', DENY) # Default DENY
      @conditions  = Array(params['conditions']).map { |c| Condition.new(c, cache) }
      @uuid = params['uuid']
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

      matching_rules(ns_resource, action).map do  |json|
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
      any_authorized = false
      find(user, action, resource).each do |rule|
        # For an explicit DENY, stop evaluating, and return false
        if rule.explicit_deny?
          return false

        elsif rule.allow?
          any_authorized = true
        end
      end

      if any_authorized
        return true
      else
        log_no_rules
        return false
      end
    end



    # @return [Boolean]
    def allow?
      result = (effect == ALLOW && conditions.all? { |c| c.met?(user,resource) } )
      if result
        log_rule_action(uuid, "allow")
      end
      return result
    end

    # @return [Boolean]
    def explicit_deny?
      result = (effect == DENY && conditions.all? { |c| c.met?(user,resource) } )
      if result
        log_rule_action(uuid, "explicitly deny")
      end
      return result
    end

    alias_method :deny?, :explicit_deny?
    private

    # The list of rules that are associated with a namespaced resource
    # and an action.
    def self.matching_rules(ns_resource, action)
      matches = storage.where(resource: ns_resource, action: action)
      log_rules(matches.map { |json| json["uuid"] } )
      return matches
    end

    # An abstraction over the storage of the rules
    # @see IronHide::Storage
    # @return [IronHide::Storage]
    def self.storage
      IronHide.storage
    end


    def self.log_rules(uuids)
      IronHide.logger.debug "Matching Rules=#{uuids.join("&")}}"
    end

    def self.log_no_rules
      IronHide.logger.debug "No matching rules"
    end

    def log_rule_action(uuid, status)
      IronHide.logger.debug "Rule matched #{uuid} with status: #{status}"
    end
  end
end
