# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::RedeployParams do
  let(:deploy) { deploys(:succeeded_test) }

  describe "#to_hash" do
    def redeploy_params_array(exact: false)
      Samson::RedeployParams.new(deploy, exact: exact).to_hash.to_a
    end

    it "returns default deploy params" do
      redeploy_params_array.must_include(
        [:reference, "staging"]
      )
    end

    it "can return exact reference" do
      redeploy_params_array(exact: true).must_include [:reference, "abcabca"]
    end

    context "when a plugin includes extra permitted params" do
      before do
        Samson::Hooks.stubs(fire: extra_params)
      end

      context "when the deploy has a has_many relation" do
        let(:extra_params) { [{items_attributes: [:uuid, :name]}] }
        let(:items) { [OpenStruct.new(uuid: "xyz", name: "item 1")] }

        before do
          deploy.stubs(items: items)
        end

        it "includes the attributes of the items in the hash" do
          redeploy_params_array.must_include(
            [:items_attributes, [{uuid: "xyz", name: "item 1"}]]
          )
        end
      end
    end

    context "unrecognized deploy hash params" do
      before do
        Samson::Hooks.callback :deploy_permitted_params do
          [{'invalid_hash' => 'one'}]
        end
      end

      it "generates a link and the invalid params are ignored" do
        redeploy_params_array.wont_include(
          [:invalid_hash, 'one']
        )
      end
    end

    context "invalid deploy param class" do
      before do
        Samson::Hooks.stubs(fire: [[['invalid_array_params']]])
      end

      it "raises an exception" do
        error = -> { redeploy_params_array }.must_raise RuntimeError
        error.message.must_equal(
          "Unsupported deploy param class: `Array` for `[\"invalid_array_params\"]`."
        )
      end
    end
  end
end
