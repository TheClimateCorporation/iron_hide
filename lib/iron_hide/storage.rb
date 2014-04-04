# IronHide::Storage provides a common interface regardless of storage type
# by implementing the Adapter pattern to decouple _how_ JSON
#
require 'multi_json'

module IronHide
  # @api private
  class Storage

    ADAPTERS = {
      file: :FileAdapter
    }

    attr_reader :adapter

    def initialize(adapter_type)
      @adapter = self.class.const_get(ADAPTERS[adapter_type]).new
    end

    # @see AbstractAdapter#where
    def where(opts = {})
      adapter.where(opts)
    end
  end

  # @abstract Subclass and override {#where} to implement an Adapter class
  class AbstractAdapter

    # @option opts [String] :resource *required*
    # @option opts [String] :action *required*
    def where(opts = {})
      raise NotImplementedError
    end
  end
end

require 'iron_hide/storage/file_adapter'
