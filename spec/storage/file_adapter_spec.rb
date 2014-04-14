require 'spec_helper'

describe IronHide::Storage::FileAdapter do
  context "when using FileAdapter" do
    before(:all) do
      IronHide.reset
      IronHide.config do |config|
        config.adapter = :file
        config.json    = File.join('spec','rules.json')
      end
    end

    let(:storage) { IronHide.storage }

    describe "#adapter" do
      it "returns a FileAdapter" do
        expect(storage.adapter).to be_instance_of(IronHide::Storage::FileAdapter)
      end
    end

    describe "#where" do
      # Examples are stored in spec/rules.json
      let(:example1) do
        [
          {
            "resource" => "com::test::TestResource",
            "action" => [ "read", "update" ],
            "description" => "Read/update access for TestResource.",
            "effect"      => "allow",
            "conditions"  => [
              {"equal"=>{"user::user_role_ids"=>["1", "2"]}}
            ]
          },
          {
            "resource" => "com::test::TestResource",
            "action" => [ "read" ],
            "description" => "Read access for TestResource.",
            "effect"      => "deny",
            "conditions"  => [
              {"equal"=>{"user::user_role_ids"=>["5"]}}
            ]
          }
        ]
      end

      context "example1" do
        it "returns all the JSON rules for a specified action/resource" do
          json = storage.where(
            resource: "com::test::TestResource",
            action: "read")

          expect(json).to eq(example1)
        end
      end

      let(:example2) do
        [
          {
            "resource" => "com::test::TestResource",
            "action" => [ "read", "update" ],
            "description" => "Read/update access for TestResource.",
            "effect"      => "allow",
            "conditions"  => [
              {"equal"=>{"user::user_role_ids"=>["1", "2"]}}
            ]
          }
        ]
      end
      context "example2" do
        it "returns all the JSON rules for a specified action/resource" do
          json = storage.where(
            resource: "com::test::TestResource",
            action: "update")

          expect(json).to eq(example2)
        end
      end

      let(:example3) do
        [
          {
            "resource" => "com::test::TestResource",
            "action"=> [ "delete" ],
            "description"=> "Delete access for TestResource",
            "effect"=> "allow",
            "conditions"=> [
              {
                "equal"=> {
                  "user::user_role_ids"=> ["1"]
                }
              }
            ]
          }
        ]
      end
      context "example3" do
        it "returns all the JSON rules for a specified action/resource" do
          json = storage.where(
            resource: "com::test::TestResource",
            action: "delete")

          expect(json).to eq(example3)
        end
      end
    end
  end
end
