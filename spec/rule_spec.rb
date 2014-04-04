require 'spec_helper'

describe IronHide::Rule do
  describe "ALLOW" do
    it "returns 'allow'" do
      expect(IronHide::Rule::ALLOW).to eq 'allow'
    end
  end

  describe "DENY" do
    it "returns 'deny'" do
      expect(IronHide::Rule::DENY).to eq 'deny'
    end
  end

  describe "::find" do
    before do
      IronHide.adapter = :file
      IronHide.json = 'spec/rules.json'
    end

    let(:action)   { 'read' }
    let(:resource) { double('test_resource') }
    let(:user)     { double('user') }

    before do
      IronHide.namespace = "com::test"
      resource.stub_chain(:class, :name) { 'TestResource' }
    end

    it "returns a collection of Rule instances that match an action and resource" do
      expect(IronHide::Rule.find(user,action,resource).first).to be_instance_of(IronHide::Rule)
    end
  end

  describe "::allow?" do
    let(:user)     { :user }
    let(:action)   { :action }
    let(:resource) { double('resource') }
    let(:rule1)    { double('rule', allow?: true, explicit_deny?: false) }
    let(:rule2)    { double('rule', allow?: true, explicit_deny?: false) }
    let(:rules)    { [ rule1, rule1, rule2 ] }

    context "when all Rules allow the action" do
      it "returns true" do
        expect(IronHide::Rule).to receive(:find).with(user,action,resource) { rules }
        expect(IronHide::Rule.allow?(user,action,resource)).to eq true
      end
    end

    context "when at least one Rule does not allow the action" do
      before { rule2.stub(allow?: false) }

      context "when it does NOT explictly deny" do
        before { rule2.stub(explicit_deny?: false) }

        it "returns true" do
          expect(IronHide::Rule).to receive(:find).with(user,action,resource) { rules }
          expect(IronHide::Rule.allow?(user,action,resource)).to eq true
        end
      end

      context "when it does explicitly deny" do
        before { rule2.stub(explicit_deny?: true) }

        it "returns false" do
          expect(IronHide::Rule).to receive(:find).with(user,action,resource) { rules }
          expect(IronHide::Rule.allow?(user,action,resource)).to eq false
        end
      end
    end

    context "when no rules match" do
      it "returns false" do
        expect(IronHide::Rule).to receive(:find).with(user,action,resource) { [] }
        expect(IronHide::Rule.allow?(user,action,resource)).to eq false
      end
    end
  end

  describe "::storage" do
    it "returns an IronHide::Storage instance" do
      expect(IronHide::Rule.storage).to be_instance_of(IronHide::Storage)
    end
  end

  let(:params) do
    {
      'action'=> :test_action,
      'effect'=> effect,
      'conditions'=> [1,2,3,4]
    }
  end

  let(:condition) { double('condition') }
  let(:user)      { double('user') }
  let(:resource)  { double('resource') }
  let(:effect)    { double('effect') }
  let(:rule)      { IronHide::Rule.new(user, resource, params) }

  describe "#initialize" do
    before { IronHide::Condition.stub(new: condition) }

    it "assigns user, action, description, effect, and conditions" do
      expect(rule.user).to eq user
      expect(rule.resource). to eq resource
      expect(rule.conditions).to eq 4.times.map { condition }
    end
  end

  describe "#allow?" do
    before { IronHide::Condition.stub(new: condition) }

    context "when at least one condition is not met" do
      before { condition.stub(:met?).and_return(true,true,true,false) }

      it "returns false" do
        expect(rule.allow?).to eq false
      end
    end

    context "when all conditions are met" do
      before { condition.stub(met?: true) }

      context "when effect is allow" do
        let(:effect) { IronHide::Rule::ALLOW }

        it "returns true" do
          expect(rule.allow?).to eq true
        end
      end

      context "when effect is deny" do
        let(:effect) { IronHide::Rule::DENY }

        it "returns false" do
          expect(rule.allow?).to eq false
        end
      end
    end

    context "when all conditions are not met" do
      before { condition.stub(met?: false) }
      let(:effect) { IronHide::Rule::ALLOW }

      it "returns false" do
        expect(rule.allow?).to eq false
      end
    end

    context "when there are no conditions" do
      let(:params) do
        {
          'action'=> :test_action,
          'effect'=> effect,
          'conditions'=> []
        }
      end

      context "when effect is ALLOW" do
        let(:effect) { IronHide::Rule::ALLOW }

        it "returns true" do
          expect(rule.allow?).to eq true
        end
      end

      context "when effect is DENY" do
        let(:effect) { IronHide::Rule::DENY }

        it "returns false" do
          expect(rule.allow?).to eq false
        end
      end
    end
  end

  describe "#explicit_deny?" do
    before { IronHide::Condition.stub(new: condition) }

    context "when at least one condition is not met" do
      before { condition.stub(:met?).and_return(true,true,true,false) }
      it "returns false" do
        expect(rule.explicit_deny?).to eq false
      end
    end

    context "when all conditions are met" do
      before { condition.stub(met?: true) }

      context "when effect is DENY" do
        let(:effect) { IronHide::Rule::DENY }

        it "returns true" do
          expect(rule.explicit_deny?).to eq true
        end
      end

      context "when effect is ALLOW" do
        let(:effect) { IronHide::Rule::ALLOW }

        it "returns false" do
          expect(rule.explicit_deny?).to eq false
        end
      end
    end

    context "when all conditions are not met" do
      before { condition.stub(met?: false) }

      it "returns false" do
        expect(rule.explicit_deny?).to eq false
      end
    end

    context "when there are no conditions" do
      let(:params) do
        {
          'action'=> :test_action,
          'effect'=> effect,
          'conditions'=> []
        }
      end

      context "when effect is ALLOW" do
        let(:effect) { IronHide::Rule::ALLOW }

        it "returns false" do
          expect(rule.explicit_deny?).to eq false
        end
      end

      context "when effect is DENY" do
        let(:effect) { IronHide::Rule::DENY }

        it "returns true" do
          expect(rule.explicit_deny?).to eq true
        end
      end
    end
  end
end
