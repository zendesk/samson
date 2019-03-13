# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe Deploy do
  let(:deploy) { deploys(:succeeded_test) }
  let(:serialized_vars) { %(VAR="thing" # ALL) }

  describe '#serialized_environment_variables' do
    let(:project) { projects(:test) }
    let(:deploy_group) { deploy_groups(:pod100) }
    let(:other_deploy_group) { deploy_groups(:pod2) }
    let(:environment) { deploy_group.environment }

    before do
      create_secret('global/global/global/baz')
      EnvironmentVariable.create!(parent: project, name: 'BAR', value: 'secret://baz')
      EnvironmentVariable.create!(parent: project, name: 'FOO', value: 'bar', scope: deploy_group)
      EnvironmentVariable.create!(parent: project, name: 'FOO', value: 'bar', scope: other_deploy_group)
      EnvironmentVariable.create!(parent: project, name: 'BAZ', value: 'baz', scope: environment)
    end

    it 'serializes env vars to string with no deploy groups' do
      EnvironmentVariable.create!(parent: project, name: 'BAR', value: 'secret://baz')
      deploy.stage.update_attribute(:deploy_groups, [])

      expected = %(BAR="secret://baz"\n)
      deploy.send(:serialized_environment_variables).must_equal expected
    end

    it 'serializes env vars to string with deploy groups' do
      deploy.stage.update_attribute(:deploy_groups, [deploy_group, other_deploy_group])

      expected = %(# Pod 100\nFOO="bar"\nBAZ="baz"\nBAR="secret://baz"\n\n# Pod2\nFOO="bar"\nBAR="secret://baz"\n)
      deploy.send(:serialized_environment_variables).must_equal expected
    end

    it 'serializes with no env vars' do
      EnvironmentVariable.destroy_all

      expected = ''
      deploy.send(:serialized_environment_variables).must_equal expected
    end
  end

  describe "#get_or_set_env_state" do
    it 'gets the env_state of a persisted deploy' do
      deploy.env_state = serialized_vars

      deploy.retrieve_env_state.must_equal serialized_vars
    end

    it 'gets the env_state of a new deploy' do
      new_deploy = Deploy.new(deploy.attributes.except('id'))
      new_deploy.expects(:serialized_environment_variables).returns(serialized_vars)

      new_deploy.retrieve_env_state.must_equal serialized_vars
    end
  end

  describe "#store_env_state" do
    it 'assigns env_state on create' do
      new_deploy = Deploy.new(deploy.attributes.except('id'))
      new_deploy.expects(:serialized_environment_variables).once.returns(serialized_vars)

      new_deploy.env_state.must_be_nil
      new_deploy.save!
      new_deploy.env_state.must_equal serialized_vars
    end
  end

  describe "#environment_variables" do
    it "can use environment variables" do
      deploy.environment_variables << EnvironmentVariable.create(
        name: "ENV_VARIABLE_ONE",
        value: "ONE"
      )
      deploy.environment_variables.count.must_equal 1
    end
  end
end
