# IronHide::Storage provides a common interface regardless of storage type
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
end


require 'iron_hide/storage/file_adapter'
