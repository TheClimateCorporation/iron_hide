require 'spec_helper'

describe IronHide::Condition do
  describe "VALID_TYPES" do
    it "returns a Hash that maps condition types to class names" do
      expect(IronHide::Condition::VALID_TYPES).to eq({
          'equal'=> :EqualCondition,
          'not_equal'=> :NotEqualCondition
        })
    end

    it "returns a frozen object" do
      expect(IronHide::Condition::VALID_TYPES).to be_frozen
    end
  end

  # The manager_id of the resource must equal the user's manager_id
  # The user's user_role_ids must include 1, 2, 3, or 4 (logical OR)
  let(:eq_params) do
    {
      'equal'=> {
        'resource::manager_id' => ['user::manager_id'] ,
        'user::user_role_ids' => [1,2,3,4]
      }
    }
  end

  # The manager_id of the resource must not equal the user's manager_id
  let(:not_eq_params) do
    {
      'not_equal'=> { 'resource::manager_id' => ['user::manager_id'] },
    }
  end

  let(:equal_condition)  { IronHide::Condition.new(eq_params) }
  let(:not_eq_condition) { IronHide::Condition.new(not_eq_params) }
  let(:user)             { double('user') }
  let(:resource)         { double('resource') }

  # See: https://github.com/rspec/rspec-mocks/issues/494
  # These objects are frozen to protect them from modification.
  # RSpec modifies the meta-class of the objects when setting method exepctations,
  # so we need to stub #freeze and render it useless.
  #
  before do
    user.stub(freeze: user)
    resource.stub(freeze: resource)
  end

  describe "::new" do
    context "when condition type is 'equal'" do
      it "returns an instance of EqualCondition" do
        expect(equal_condition).to be_instance_of(IronHide::EqualCondition)
      end
    end

    context "when condition type is 'not_equal'" do
      it "returns an instance of EqualCondition" do
        expect(not_eq_condition).to be_instance_of(IronHide::NotEqualCondition)
      end
    end

    context "when more than 1 key present in params" do
      let(:invalid_params) { not_eq_params.merge(eq_params) }

      it "raises IronHide::InvalidConditional exception" do
        expect{IronHide::Condition.new(invalid_params)}.to raise_error(IronHide::InvalidConditional)
      end
    end

    context "when condition type is unknown" do
      let(:invalid_params) { { 'wrong' => { 'resource::manager_id' => ['user::manager_id']} } }

      it "raises an error" do
        expect{IronHide::Condition.new(invalid_params)}.to raise_error(IronHide::InvalidConditional)
      end
    end
  end

  describe "#met?" do
    context "when condition type is 'equal'" do
      context "when all expressions in the condition are met (logical AND)" do

        let(:role_ids)  { [1,2] }
        let(:manager_id) { 99 }

        before do
          user.stub(user_role_ids: role_ids, manager_id: manager_id)
          resource.stub(manager_id: manager_id)
        end

        it "returns true" do
          expect(equal_condition.met?(user, resource)).to eq true
        end
      end

      context "when all expressions in the condition are not met" do

        let(:role_ids)  { [] }
        let(:manager_id) { 99 }

        before do
          user.stub(user_role_ids: role_ids, manager_id: manager_id)
          resource.stub(manager_id: manager_id)
        end

        it "returns false" do
          expect(equal_condition.met?(user,resource)).to eq false
        end
      end

      context "when conditional expressions are empty" do
        before { eq_params['equal'] = {} }
        it "returns true" do
          expect(equal_condition.met?(user,resource)).to eq true
        end
      end
    end

    context "when condition type is :not_equal" do
      context "when all expressions in the condition are met (logical AND)" do

        let(:manager_id) { 99 }

        before do
          user.stub(manager_id: manager_id)
          # Satisfy the condition that manager_id of the resource and user don't match
          resource.stub(manager_id: manager_id + 1)
        end

        it "returns true" do
          expect(not_eq_condition.met?(user,resource)).to eq true
        end
      end

      context "when all expressions in the condition are not met" do
        # Don't satisfy the condition by setting the manager_ids on user
        # and resource to be the same
        let(:manager_id) { 99 }

        before do
          user.stub(manager_id: manager_id)
          resource.stub(manager_id: manager_id)
        end

        it "returns false" do
          expect(not_eq_condition.met?(user,resource)).to eq false
        end
      end

      context "when conditional expressions are empty" do
        before { not_eq_params['not_equal'] = {} }
        it "returns true" do
          expect(not_eq_condition.met?(user,resource)).to eq true
        end
      end
    end

    context "when conditional expressions are invalid" do
      context "when key is invalid" do
        # The key can only reference a 'user' or 'resource', otherwise,
        # it's an invalid expression
        let(:eq_params) do
          {
            'equal' => {
              'something_wrong::manager_id' => ['user::manager_id'] ,
              'user::user_role_ids' => [1,2,3,4]
            }
          }
        end

        it "raises an InvalidConditional error" do
          expect{equal_condition.met?(user, resource)}.to raise_error(IronHide::InvalidConditional)
        end
      end

      context "when value is nil" do
        before { user.stub(manager_id: 1) }

        let(:eq_params) do
          {
            'equal' => nil
          }
        end

        it "raises an InvalidConditional error" do
          expect{equal_condition.met?(user, resource)}.to raise_error(IronHide::InvalidConditional)
        end
      end

      context "when value is wrong type" do
        before { user.stub(manager_id: 1) }

        let(:eq_params) do
          {
            'equal' => "wrong_type"
          }
        end

        it "raises an InvalidConditional error" do
          expect{equal_condition.met?(user, resource)}.to raise_error(IronHide::InvalidConditional)
        end
      end
    end

    #TODO: Additional tests.
    # duplication of the same information that conflicts / conditions that cannot be satisfied
  end

  describe "#evaluate" do
    before do
      user.stub(manager_id: 1)
      resource.stub(manager_id: 5)
    end

    let(:condition) { IronHide::Condition.new(eq_params) }

    context "when input is a valid expression" do
      let(:input1) { 'user::manager_id' }
      let(:input2) { 'resource::manager_id' }
      let(:input3) { 'user' }
      let(:input4) { 'resource' }

      it "returns the evaluated expression" do
        expect(condition.send(:evaluate, input1, user, resource)).to eq [1]
        expect(condition.send(:evaluate, input2, user, resource)).to eq [5]
        expect(condition.send(:evaluate, input3, user, resource)).to eq [user]
        expect(condition.send(:evaluate, input4, user, resource)).to eq [resource]
      end
    end

    context "when input is not a valid expression" do
      let(:input1) { 'user::instance_eval()' }
      let(:input2) { 'user::delete!' }
      let(:input3) { 'user::id=' }
      let(:input4) { 'user::' }
      let(:input5) { 'user::something::' }

      it "returns the input" do
        expect(condition.send(:evaluate, input1, user, resource)).to eq [input1]
        expect(condition.send(:evaluate, input2, user, resource)).to eq [input2]
        expect(condition.send(:evaluate, input3, user, resource)).to eq [input3]
        expect(condition.send(:evaluate, input4, user, resource)).to eq [input4]
        expect(condition.send(:evaluate, input5, user, resource)).to eq [input5]
      end
    end
  end
end
