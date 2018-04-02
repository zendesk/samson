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

    before do
      create_secret('global/global/global/baz')
      EnvironmentVariable.create!(parent: project, name: 'BAR', value: 'secret://baz')
      EnvironmentVariable.create!(parent: project, name: 'FOO', value: 'bar', scope: other_deploy_group)
      EnvironmentVariable.create!(parent: project, name: 'DING', value: 'dong', scope: deploy_group)
      EnvironmentVariable.create!(parent: project, name: 'COOL', value: 'beans', scope: environments(:production))
    end

    it 'serializes env vars to string with no deploy groups' do
      deploy.stage.update_attribute(:deploy_groups, [])

      expected = %(BAR="secret://baz" # All\nCOOL="beans" # Production\nDING="dong" # Pod 100\nFOO="bar" # Pod2)
      deploy.send(:serialized_environment_variables).must_equal expected
    end

    it 'serializes env state to string scoped to deploy groups' do
      expected = %(BAR="secret://baz" # All\nDING="dong" # Pod 100)
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
end
