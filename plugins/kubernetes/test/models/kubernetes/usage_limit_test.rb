# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::UsageLimit do
  def create_limit(attributes = {})
    Kubernetes::UsageLimit.create!(attributes.merge(cpu: 1, memory: 2))
  end

  let(:project) { projects(:test) }
  let(:deploy_group) { deploy_groups(:pod100) }

  describe ".most_specific" do
    let!(:usage_limit) { create_limit }

    it "finds no match" do
      usage_limit.destroy!
      Kubernetes::UsageLimit.most_specific(project, deploy_group).must_be_nil
    end

    it "matches without project" do
      Kubernetes::UsageLimit.most_specific(project, deploy_group).must_equal usage_limit
    end

    it "matches by priority" do
      found = create_limit project: project
      create_limit scope: deploy_group
      Kubernetes::UsageLimit.most_specific(project, deploy_group).must_equal found
    end

    it "matches by environment" do
      found = create_limit scope: deploy_group.environment, project: project
      create_limit scope: deploy_group.environment
      Kubernetes::UsageLimit.most_specific(project, deploy_group).must_equal found
    end

    it "matches by deploy group" do
      create_limit scope: deploy_group.environment, project: project
      found = create_limit scope: deploy_group, project: project
      create_limit scope: deploy_group.environment
      Kubernetes::UsageLimit.most_specific(project, deploy_group).must_equal found
    end
  end
end
