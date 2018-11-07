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
    it "returns an array of hashes" do
      Samson::Hooks.only_callbacks_for_plugin('deploy_env_vars', :deploy_env) do
        Samson::Hooks.fire(:deploy_env, deploy).must_equal([{}])
      end
    end

    it "returns an array of hashes containing the deploy environment variables" do
      deploy.environment_variables.create!(name: "TWO", value: "2")
      Samson::Hooks.fire(:deploy_env, deploy).must_include("TWO" => "2")
    end
  end
end
