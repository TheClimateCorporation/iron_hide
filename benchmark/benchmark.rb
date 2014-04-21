#!/usr/bin/env ruby

require 'iron_hide'
require 'multi_json'
require 'tempfile'
require 'benchmark'
require 'json/ext'

User     = Class.new
Resource = Class.new

class BenchmarkTest

  attr_reader :num, :expensive, :cache

  # @param [Integer] num is the number of rules to benchmark with
  # @param [Boolean] expensive tests the effect of a repeated, expensive
  #                  attribute/method call in the rules
  # @param [Boolean] cache turn attribution evaluation caching on or off
  def initialize(num, expensive = false, cache = true)
    @num       = num
    @expensive = expensive
    @cache     = cache
  end

  def test
    num       = @num
    expensive = @expensive

    [ User, Resource ].each do |klass|
      klass.instance_eval do
        num.times do |n|
          # Dynamically create num attributes
          # i.e., :attr0, :attr1, :attr(num-1)
          define_method("attr#{n}") do
            return 10
          end
        end
      end
    end

    User.instance_eval do
      define_method(:expensive_attr) do
        # Sleep for 10 if :expensive is true
        sleep(expensive ? 1 : 0) and true
      end
    end

    @rules = begin
      num.times.map do |n|
        {
          :resource   => 'benchmark::Resource',
          :action     => ['read'],
          :effect     => 'allow',
          :conditions => [
            { :equal => { "user::expensive_attr" => ["1"] } },
            { :equal => { "user::attr#{n}" => ["resource::attr#{n}"] } }
          ]
        }
      end
    end

    @file = Tempfile.new('rules.json')
    File.open(@file, 'w+') { |f| f << MultiJson.dump(@rules) }
    @file.rewind

    IronHide.reset
    IronHide.configure do |config|
      config.namespace = 'benchmark'
      config.json      = @file.path
      config.memoize   = @cache
    end

    @resource = Resource.new
    @user     = User.new
    IronHide.can?(@user, :read, @resource)

  ensure
    @file.close
  end
end

ten                    = BenchmarkTest.new(10)
ten_expensive_cache    = BenchmarkTest.new(10,true)
ten_expensive_no_cache = BenchmarkTest.new(10,true, false)
thousand               = BenchmarkTest.new(1000)
hundred_thousand       = BenchmarkTest.new(100_000)

Benchmark.bm do |b|
  b.report("10                      ") { ten.test}
  b.report("10 - Expensive          ") { ten_expensive_cache.test}
  b.report("10 - Expensive: No Cache") { ten_expensive_no_cache.test}
  b.report("1000                    ") { thousand.test}
  b.report("100_000                 ") { hundred_thousand.test}
end
