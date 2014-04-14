require 'spec_helper'

describe IronHide::Configuration do
  describe "defaults" do
    it "initializes with default configuration variables" do
      configuration = IronHide::Configuration.new

      expect(configuration.adapter).to eq :file
      expect(configuration.namespace).to eq 'com::IronHide'
      expect(configuration.json).to eq nil
    end
  end

  describe "::add_configuration" do
    it "creates an accessor and default values for additional configuration variables" do
      configuration = IronHide::Configuration.new

      configuration.add_configuration(var1: :default1, var2: :default2, var3: nil)

      expect(configuration.var1).to eq :default1
      expect(configuration.var2).to eq :default2

      configuration.var3 = :nondefault
      expect(configuration.var3).to eq :nondefault
    end
  end
end
