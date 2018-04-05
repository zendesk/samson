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

  describe :job_additional_vars do
    context "if the job does not have a deploy" do
      let(:user) { users(:admin) }
      let(:project) { projects(:test) }
      let(:job) { project.jobs.create!(command: 'cat foo', user: user, project: project) }

      it "returns nil" do
        Samson::Hooks.fire(:job_additional_vars, job).must_equal([nil])
      end
    end

    context "if the job does have a deploy" do
      let(:job) { jobs(:succeeded_test) }

      context "if the deploy does not have any env variables" do
        it "returns an empty hash" do
          Samson::Hooks.fire(:job_additional_vars, job).must_equal([{}])
        end
      end

      context "if the deploy has environment variables" do
        before do
          job.deploy.environment_variables << EnvironmentVariable.create(
            name: "ENV_VARIABLE_TWO",
            value: "TWO"
          )
        end

        it "returns a hash with the deploy environment variables" do
          Samson::Hooks.fire(:job_additional_vars, job).must_equal([{
            "ENV_VARIABLE_TWO" => "TWO"
          }])
        end
      end
    end
  end
end
