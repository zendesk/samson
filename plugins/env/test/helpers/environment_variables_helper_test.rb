# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe EnvironmentVariablesHelper do
  describe "#deploy_environment_variable_diff" do
    let(:deploy) { deploys(:succeeded_test) }

    before { @deploy = deploy }

    it "returns no diff when there is none" do
      deploy_environment_variable_diff.must_be_nil
    end

    it "does not fail without a stage" do
      @deploy.stage = nil
      deploy_environment_variable_diff.must_be_nil
    end

    it 'returns diff for new deploy' do
      @deploy = Deploy.new(deploy.attributes.except('id', 'created_at', 'updated_at'))
      @deploy.expects(:serialized_environment_variables).returns('THING=thing # All')
      deploy_environment_variable_diff.must_equal [nil, "THING=thing # All"]
    end

    it 'returns diff with preexisting deploy' do
      @deploy = Deploy.create!(deploy.attributes.except('id', 'created_at', 'updated_at'))
      @deploy.env_state = "a\nb\nc"
      deploy_environment_variable_diff.must_equal [nil, "a\nb\nc"]
    end

    it 'returns no diff when env_state is the same' do
      @deploy = Deploy.create!(deploy.attributes.except('id', 'created_at', 'updated_at'))
      deploy_environment_variable_diff.must_be_nil
    end

    it "caches nils" do
      @deploy.expects(:project).once
      2.times { deploy_environment_variable_diff.must_be_nil }
    end
  end
end
