# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::UsageLimit do
  def create_limit(attributes = {})
    Kubernetes::UsageLimit.create!({cpu: 1, memory: 2, project: projects(:other)}.merge(attributes))
  end

  let(:project) { projects(:test) }
  let(:deploy_group) { deploy_groups(:pod100) }

  describe "validations" do
    it "does not allow duplicate limits in the same scope" do
      create_limit
      limit = Kubernetes::UsageLimit.new(cpu: 1, memory: 2, project: projects(:other))
      refute_valid limit
      limit.errors.full_messages.must_equal ["Scope has already been taken"]
    end

    it "allows duplicate limits in different scope" do
      create_limit
      assert_valid Kubernetes::UsageLimit.new(cpu: 1, memory: 2, scope: environments(:staging))
    end

    describe "#validate_wildcard" do
      it "does not allow unscoped" do
        limit = Kubernetes::UsageLimit.new(cpu: 1, memory: 2)
        refute_valid limit
        limit.errors.full_messages.must_equal ["Non-zero limits without scope and project are not allowed"]
      end

      it "allows unscoped 0 so users can disable everything" do
        assert_valid Kubernetes::UsageLimit.new(cpu: 0, memory: 0)
      end

      it "allow scoped" do
        assert_valid Kubernetes::UsageLimit.new(cpu: 1, memory: 2, scope: environments(:staging))
      end

      it "allow unscoped with ENV flag" do
        with_env KUBERNETES_ALLOW_WILDCARD_LIMITS: "true" do
          assert_valid Kubernetes::UsageLimit.new(cpu: 1, memory: 2)
        end
      end
    end
  end

  describe ".most_specific" do
    let!(:usage_limit) { create_limit }

    it "finds no match" do
      usage_limit.destroy!
      Kubernetes::UsageLimit.most_specific(project, deploy_group).must_be_nil
    end

    it "matches without project" do
      usage_limit.update(scope: deploy_group, project: nil)
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

  describe "#priority" do
    let(:limit) { create_limit(scope: environments(:staging)) }

    it "is high with project" do
      limit.priority.must_equal [0, 1]
    end

    it "is low when global" do
      limit.project = nil
      limit.priority.must_equal [1, 1]
    end
  end
end
