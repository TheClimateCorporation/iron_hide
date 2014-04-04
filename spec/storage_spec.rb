require 'spec_helper'

describe IronHide::Storage do
  describe "ADAPTERS" do
    it "returns a Hash of valid adapter types" do
      expect(IronHide::Storage::ADAPTERS).to eq(
        {
          file: :FileAdapter
        }
      )
    end
  end
end
