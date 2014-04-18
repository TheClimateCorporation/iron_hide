require 'set'

module IronHide
  class Condition
    VALID_TYPES = {
      'equal'=> :EqualCondition,
      'not_equal'=> :NotEqualCondition
    }.freeze

    # @param params [Hash] It has a single key, which is the conditional operator
    #   type. The value is the set of conditionals that must be met.
    #
    # @example
    #   { :equal => {
    #       'resource::manager_id' => ['user::manager_id'],
    #       'user::user_role_ids' => ['8']
    #     }
    #   }
    #
    # @return [EqualCondition, NotEqualCondition]
    # @raise [IronHide::InvalidConditional] for too many keys
    #
    def self.new(params, cache = NullCache.new)
      if params.length > 1
        raise InvalidConditional, "Expected #{params} to have one key"
      end
      type, conditionals = params.first
      #=> :equal, { key: val, key: val }
      #
      # See: http://ruby-doc.org/core-1.9.3/Class.html#method-i-allocate
      klass = VALID_TYPES.fetch(type){ raise InvalidConditional, "#{type} is not valid"}
      cond  = IronHide.const_get(klass).allocate
      cond.send(:initialize, conditionals, cache)
      cond
    end

    # @param conditionals [Hash]
    # @example
    #  {
    #    'resource::manager_id' => ['user::manager_id'],
    #    'user::user_role_ids' => ['8']
    #  }
    #
    # @param [IronHide::SimpleCache, IronHide::NullCache] cache
    #
    def initialize(conditionals, cache)
      @conditionals = conditionals
      @cache        = cache
    end

    attr_reader :conditionals, :cache

    # @param user [Object]
    # @param resource [Object]
    # return [Boolean] if is met
    def met?(user, resource)
      raise NotImplementedError
    end

    protected

    EVALUATE_REGEX = /
      (
       \Auser\z|    # 'user' or 'resource'
       \Aresource\z
      )
      |             # OR
      \A\w+:{2}\w+  # "word::word"
      (:{2}\w+)*    # Followed by any number of "::word"
      \z            # End of string
      /x

    # *Safely* evaluate a conditional expression
    #
    # @note
    # This does not guarantee that conditions are correctly specified.
    # For example, 'user:::manager' will not resolve to anything, and
    # and an exception will *not* be raised. The same goes for 'user:::' and
    # 'user:id'.
    #
    # @param expressions [Array<String, Object>, String, Object] an array or
    # a single expression. This represents either an immediate value (e.g.,
    # '1', 99) or a valid expression that can be interpreted (see example)
    #
    # @example
    #   ['user::manager_id']     #=> [1]
    #   ['user::role_ids']       #=> [1,2,3,4]
    #   ['resource::manager_id'] #=> [1]
    #   [1,2,3,4]                #=> [1,2,3,4]
    #   'user::id'               #=> [1]
    #   'resource::id'           #=> [2]
    #
    # @return [Array<Object>] a collection of 0 or more objects
    # representing attributes on the user or resource
    #
    def evaluate(expression, user, resource)
      Array(expression).flat_map do |el|
        if expression?(el)
          cache.fetch(el) {
            type, *ary  = el.split('::')
            if type == 'user'
              Array(ary.inject(user) do |rval, attr|
                rval.freeze.public_send(attr)
              end)
            elsif type == 'resource'
              Array(ary.inject(resource) do |rval, attr|
                rval.freeze.public_send(attr)
              end)
            else
              raise "Expected #{type} to be 'resource' or 'user'"
            end
          }
        else
          el
        end
      end
    end

    def expression?(expression)
      !!(expression =~ EVALUATE_REGEX)
    end

    def with_error_handling
      yield
    rescue => e
      new_exception = InvalidConditional.new(e.to_s)
      new_exception.set_backtrace(e.backtrace)
      raise new_exception
    end
  end

  # @api private
  class EqualCondition < Condition
    def met?(user, resource)
      with_error_handling do
        conditionals.all? do |left, right|
          (evaluate(left, user, resource) & evaluate(right, user, resource)).size > 0
        end
      end
    end
  end

  # @api private
  class NotEqualCondition < Condition
    def met?(user, resource)
      with_error_handling do
        conditionals.all? do |left, right|
          !((evaluate(left, user, resource) & evaluate(right, user, resource)).size > 0)
        end
      end
    end
  end
end
