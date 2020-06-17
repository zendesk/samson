# frozen_string_literal: true
require_relative "../test_helper"
require "kubeclient"

SingleCov.covered!

describe SamsonKubernetes do
  describe :project_permitted_params do
    it "adds ours" do
      Samson::Hooks.fire(:project_permitted_params).flatten(1).must_include :kubernetes_rollout_timeout
    end
  end

  describe :stage_permitted_params do
    it "adds ours" do
      Samson::Hooks.fire(:stage_permitted_params).flatten(1).must_include :kubernetes
    end
  end

  describe :deploy_permitted_params do
    it "adds ours" do
      params = Samson::Hooks.fire(:deploy_permitted_params).flatten(1)
      params.must_include :kubernetes_rollback
      params.must_include :kubernetes_reuse_build
    end
  end

  describe :deploy_group_permitted_params do
    it "adds ours" do
      params = Samson::Hooks.fire(:deploy_group_permitted_params).flatten(1)
      params.must_include cluster_deploy_group_attributes: [:id, :kubernetes_cluster_id, :namespace]
    end
  end

  describe :link_parts_for_resource do
    def link_parts(resource)
      Samson::Hooks.fire(:link_parts_for_resource).to_h.fetch(resource.class.name).call(resource)
    end

    it "links to deploy group role" do
      dg_role = kubernetes_deploy_group_roles(:test_pod1_app_server)
      link_parts(dg_role).must_equal ["Foo role app-server for Pod1", [dg_role.project, dg_role]]
    end

    it "links to role" do
      role = kubernetes_roles(:app_server)
      link_parts(role).must_equal ["Foo role app-server", [role.project, role]]
    end

    it "links to limit" do
      limit = Kubernetes::UsageLimit.create!(memory: 10, cpu: 10, scope: environments(:production))
      link_parts(limit).must_equal ["Limit for Production on All", limit]
    end

    it "links to cluster" do
      cluster = kubernetes_clusters(:test_cluster)
      link_parts(cluster).must_equal ["test", cluster]
    end

    it "links to namespace" do
      namespace = kubernetes_namespaces(:test)
      link_parts(namespace).must_equal ["test", namespace]
    end
  end

  describe :stage_clone do
    def stage_clone(old_stage, new_stage)
      Samson::Hooks.fire(:stage_clone, old_stage, new_stage)
    end

    before do
      @old_stage = stages(:test_staging)
      @new_stage = stages(:test_production)

      # only go to pod2 which has no roles
      @new_stage.deploy_groups_stages.detect { |dgs| dgs.deploy_group == deploy_groups(:pod1) }.destroy
      @new_stage.reload
    end

    it 'does not create duplicate deploy group roles' do
      assert_difference 'Kubernetes::DeployGroupRole.count', 2 do
        2.times { stage_clone(@old_stage, @new_stage) }
      end
    end

    it 'copies old stage deploy groups to new stage' do
      stage_clone(@old_stage, @new_stage)

      old_stage_dgr = kubernetes_deploy_group_roles(:test_pod100_app_server)
      new_stage_dgr = Kubernetes::DeployGroupRole.where(kubernetes_role: old_stage_dgr.kubernetes_role).last
      old_stage_dgr.wont_equal new_stage_dgr

      ignore = ['id', 'created_at', 'updated_at', 'deploy_group_id']
      new_stage_dgr.attributes.except(*ignore).must_equal old_stage_dgr.attributes.except(*ignore)
    end

    it "copies kubernetes_stage_roles" do
      @old_stage.kubernetes_stage_roles.create!(kubernetes_role: kubernetes_roles(:app_server))
      stage_clone(@old_stage, @new_stage)
      @new_stage.kubernetes_stage_roles.map(&:kubernetes_role).must_equal [kubernetes_roles(:app_server)]
    end
  end

  describe ".connection_errors" do
    it "works" do
      SamsonKubernetes.connection_errors
    end
  end

  describe ".retry_on_connection_errors" do
    it "retries" do
      count = 0
      assert_raises OpenSSL::SSL::SSLError do
        SamsonKubernetes.retry_on_connection_errors do
          count += 1
          raise OpenSSL::SSL::SSLError
        end
      end
      count.must_equal SamsonKubernetes::API_RETRIES + 1
    end

    it "retries generic kubeclient errors" do
      count = 0
      assert_raises Kubeclient::HttpError do
        SamsonKubernetes.retry_on_connection_errors do
          count += 1
          raise Kubeclient::HttpError.new(123, 'x', nil)
        end
      end
      count.must_equal SamsonKubernetes::API_RETRIES + 1
    end

    it "does not retry 404s" do
      count = 0
      assert_raises Kubeclient::ResourceNotFoundError do
        SamsonKubernetes.retry_on_connection_errors do
          count += 1
          raise Kubeclient::ResourceNotFoundError.new(404, 'x', nil)
        end
      end
      count.must_equal 1
    end
  end
end
