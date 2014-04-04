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

  describe "::adapter=" do
    it "sets the storage adapter type" do
      type = :file
      IronHide.adapter = type
      expect(IronHide.adapter).to eq type
    end
  end

  describe "::json=" do
    it "sets the file path for the JSON rules file (used for the JSON adapter)" do
      IronHide.json = 'file/path'
      expect(IronHide.json).to eq ['file/path']
    end
  end

  describe "::storage" do
    context "when an adapter type is not specified" do
      before { IronHide.reset }
      it "raises an exception" do
        expect{IronHide.storage}.to raise_error(IronHide::IronHideError)
      end
    end

    context "when an adapter type is specified" do
      before do
        IronHide.adapter = :file
        IronHide.json    = 'spec/rules.json'
      end

      it "returns an IronHide::Storage object" do
        expect(IronHide.storage).to be_instance_of(IronHide::Storage)
      end
    end
  end

  describe "::namespace" do
    context "when namespace is not set" do
      before { IronHide.namespace = nil }

      it "returns default" do
        expect(IronHide.namespace).to eq 'com::IronHide'
      end
    end

    context "when namespace is set" do
      before { IronHide.namespace = 'namespace' }
      after  { IronHide.namespace = nil }

      it "returns namespace" do
        expect(IronHide.namespace).to eq 'namespace'
      end
    end
  end

  describe "::config" do
    it "yields self" do
      expect{|b| IronHide.config(&b) }.to yield_with_args(IronHide)
    end
  end
end
