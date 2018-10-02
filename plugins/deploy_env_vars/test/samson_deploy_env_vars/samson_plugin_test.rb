# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonDeployEnvVars do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe :deploy_permitted_params do
    it "includes the environment_variables attributes" do
      Samson::Hooks.fire(:deploy_permitted_params).must_include(
        environment_variables_attributes: [
          :name, :value, :scope_type_and_id, :_destroy, :id
        ]
      )
    end
  end

  describe :deploy_env do
    it "returns an empty hash" do
      Samson::Hooks.fire(:deploy_env, deploy).must_equal([{}])
    end

    it "returns a hash with the deploy environment variables" do
      deploy.environment_variables.create!(name: "TWO", value: "2")
      Samson::Hooks.fire(:deploy_env, deploy).must_equal([{
        "TWO" => "2"
      }])
    end
  end
end
