require 'spec_helper'
require 'tempfile'
require 'stringio'

describe "Integration Testing" do
  before(:all) do
    @file = Tempfile.new('rules')
    @file.write <<-RULES
      [
        {
          "uuid" : "1123-aabc-rand-ishard",
          "resource": "com::test::TestResource",
          "action": ["read", "write"],
          "description": "Read/write access for TestResource.",
          "effect": "allow",
          "conditions": [
            {
              "equal": {
                "user::role_ids": [1],
                "user::name": ["Cyril Figgis"]
              }
            }
          ]
        },
        {
          "uuid" : "enjoyTheCamelCaseAlan",
          "resource": "com::test::TestResource",
          "action": ["disable"],
          "description": "Read/write access for TestResource.",
          "effect": "deny",
          "conditions": [
            {
              "equal": {
                "user::role_ids": [99]
              }
            }
          ]
        },
        {
          "uuid" : "It's an opaque string, you shouldn't care",
          "resource": "com::test::TestResource",
          "action": ["read"],
          "description": "Read access for TestResource.",
          "effect": "allow",
          "conditions": [
            {
              "equal": {
                "user::role_ids": [5]
              }
            }
          ]
        },
        {
          "uuid" : "butYouKnowItKillsYooooooouu",
          "resource": "com::test::TestResource",
          "action": ["read"],
          "effect": "deny",
          "conditions": [
            {
              "equal": {
                "resource::active": [false]
              }
            }
          ]
        },
        {
          "uuid" : "Less Fun now",
          "resource": "com::test::TestResource",
          "action": ["destroy"],
          "effect": "allow",
          "description": "Rule with multiple conditions",
          "conditions": [
            {
              "equal": {
                "resource::active": [false]
              }
            },
            {
              "not_equal": {
                "user::role_ids": [954]
              }
            }
          ]
        },
        {
          "uuid" : "So maaany tests?",
          "resource": "com::test::TestResource",
          "action": ["fire"],
          "effect": "allow",
          "description": "Rule with nested attributes",
          "conditions": [
            {
              "equal": {
                "user::manager::name": ["Lumbergh"]
              }
            }
          ]
        }
      ]
    RULES
    @file.rewind
    IronHide.configure do |config|
      config.adapter   = :file
      config.json      = @file.path
      config.namespace = "com::test"
    end
  end

  after(:all) { @file.close }

  class TestUser
    attr_accessor :role_ids, :name
    def initialize
      @role_ids = []
    end

    def manager
      @manager ||= TestUser.new
    end
  end

  class TestResource
    attr_accessor :active
  end

  let(:user)     { TestUser.new }
  let(:resource) { TestResource.new }

  context "when one rule matches an action" do
    context "when effect is 'allow'" do
      let(:action) { 'write' }
      let(:rules)  { IronHide::Rule.find(user,action,resource) }
      specify      { expect(rules.size).to eq 1 }
      specify      { expect(rules.first.effect).to eq 'allow' }

      context "when all conditions are met" do
        before do
          user.role_ids << 1 << 2
          user.name = 'Cyril Figgis'
        end

        specify { expect(IronHide.can?(user,action,resource)).to be_true }
        specify { expect{IronHide.authorize!(user,action,resource)}.to_not raise_error }
      end

      context "when some conditions are met" do
        before do
          user.role_ids << 1 << 2
          user.name = 'Pam'
        end

        specify { expect(IronHide.can?(user,action,resource)).to be_false }
        specify { expect{IronHide.authorize!(user,action,resource)}.to raise_error }
      end
    end

    context "when effect is 'deny'" do
      let(:action) { 'disable' }
      let(:rules)  { IronHide::Rule.find(user,action,resource) }
      specify      { expect(rules.size).to eq 1 }
      specify      { expect(rules.first.effect).to eq 'deny' }

      context "when all conditions are met" do
        before { user.role_ids << 99 }
        specify { expect(IronHide.can?(user,action,resource)).to be_false }
        specify { expect{IronHide.authorize!(user,action,resource)}.to raise_error }
      end

      context "when no conditions are met" do
        specify { expect(IronHide.can?(user,action,resource)).to be_false }
        specify { expect{IronHide.authorize!(user,action,resource)}.to raise_error }
      end
    end
  end

  context "when no rule matches an action" do
    let(:action) { 'some-crazy-rule' }
    let(:rules)  { IronHide::Rule.find(user,action,resource) }
    specify      { expect(rules.size).to eq 0 }
    specify { expect(IronHide.can?(user,action,resource)).to be_false }
    specify { expect{IronHide.authorize!(user,action,resource)}.to raise_error }
  end

  context "when multiple rules match an action" do
    let(:action) { 'read' }
    let(:rules)  { IronHide::Rule.find(user,action,resource) }
    specify      { expect(rules.size).to eq 3 }

    context "when conditions for only one rule are met" do
      context "when effect is 'allow'" do
        before  { user.role_ids << 5 }
        specify { expect(IronHide.can?(user,action,resource)).to be_true }
        specify { expect{IronHide.authorize!(user,action,resource)}.to_not raise_error }
      end

      context "when effect is 'deny'" do
        before { resource.active = false }
        specify { expect(IronHide.can?(user,action,resource)).to be_false }
        specify { expect{IronHide.authorize!(user,action,resource)}.to raise_error }
      end
    end

    context "when conditions for all rules are met" do
      context "when at least one rule's effect is 'deny'" do
        before  do
          resource.active = false
          user.name = 'Cyril Figgis'
          user.role_ids << 5
        end

        specify { expect(IronHide.can?(user,action,resource)).to be_false }
        specify { expect{IronHide.authorize!(user,action,resource)}.to raise_error }
      end
    end
  end

  describe "testing rule with multiple conditions" do
    let(:action) { 'destroy' }
    let(:rules)  { IronHide::Rule.find(user,action,resource) }
    specify      { expect(rules.size).to eq 1 }
    context "when only one condition is met" do
      before  { resource.active = false ; user.role_ids << 954 }
      specify { expect(IronHide.can?(user,action,resource)).to be_false }
      specify { expect{IronHide.authorize!(user,action,resource)}.to raise_error }
    end

    context "when all conditions are met" do
      before  { resource.active = false ; user.role_ids << 25 }
      specify { expect(IronHide.can?(user,action,resource)).to be_true }
      specify { expect{IronHide.authorize!(user,action,resource)}.to_not raise_error }
    end
  end

  describe "testing rule with nested attributes" do
    let(:action) { 'fire' }
    let(:rules)  { IronHide::Rule.find(user,action,resource) }
    context "when conditions are met" do
      before  { user.manager.name = "Lumbergh" }
      specify { expect(IronHide.can?(user,action,resource)).to be_true }
      specify { expect{IronHide.authorize!(user,action,resource)}.to_not raise_error }
    end
    context "when conditions are not met" do
      before  { user.manager.name = "Phil" }
      specify { expect(IronHide.can?(user,action,resource)).to be_false }
      specify { expect{IronHide.authorize!(user,action,resource)}.to raise_error }
    end
  end


  describe "it should support logging" do
    begin
      initial_logger = IronHide.logger
      dummy_file = StringIO.new
      IronHide.config {|c| c.logger = Logger.new dummy_file }

      IronHide.logger.error "Logging output"
      dummy_file.rewind

      specify { expect(dummy_file.read).to match(/Logging output/) }

      IronHide.config {|c| c.logger = initial_logger }
    end
  end
end

