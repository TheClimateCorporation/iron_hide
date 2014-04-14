require 'spec_helper'

describe IronHide do
  let(:user)     { double('user') }
  let(:action)   { double('action') }
  let(:resource) { double('resource') }

  describe "::authorize!" do
    context "when the rules allow" do
      before do
        IronHide::Rule.stub(:allow?)
          .with(user,action.to_s,resource) { true }
      end

      it "returns true" do
        expect(IronHide.authorize!(user, action, resource)).to eq true
      end
    end

    context "when the rules do not allow" do
      before do
        IronHide::Rule.stub(:allow?)
          .with(user,action.to_s,resource) { false }
      end

      it "raise IronHide::AuthorizationError" do
        expect{IronHide.authorize!(user, action, resource)}.to raise_error(IronHide::AuthorizationError)
      end
    end
  end

  describe "::can?" do
    context "when the rules allow" do
      before do
        IronHide::Rule.stub(:allow?)
          .with(user,action.to_s,resource) { true }
      end

      it "returns true" do
        expect(IronHide.can?(user, action, resource)).to eq true
      end
    end
    context "when the rules do not allow" do
      before do
        IronHide::Rule.stub(:allow?)
          .with(user,action.to_s,resource) { false }
      end

      it "returns false" do
        expect(IronHide.can?(user, action, resource)).to eq false
      end
    end
  end

  describe "::storage" do
    before do
      IronHide.configure do |config|
        config.adapter = :file
        config.json    = 'spec/rules.json'
      end
    end

    it "returns an IronHide::Storage object" do
      expect(IronHide.storage).to be_instance_of(IronHide::Storage)
    end
  end
end
