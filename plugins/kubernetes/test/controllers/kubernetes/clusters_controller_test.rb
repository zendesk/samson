# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::ClustersController do
  def self.use_example_config
    around { |t| with_example_kube_config { |f| with_env "KUBE_CONFIG_FILE": f, &t } }
  end

  let(:cluster) { create_kubernetes_cluster }

  unauthorized :get, :index
  unauthorized :get, :show, id: 1

  as_a :viewer do
    describe "#index" do
      it "renders" do
        get :index
        assert_template :index
      end

      it "renders capacity" do
        stub_request(:get, "http://foobar.server/api/v1/nodes").to_return(body: {items: []}.to_json)
        get :index, params: {capacity: true}
        assert_template :index
      end
    end

    describe "#show" do
      use_example_config

      it "renders" do
        get :show, params: {id: cluster.id}
        assert_template :show
      end
    end
  end

  as_a :deployer do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :get, :edit, id: 1
    unauthorized :patch, :update, id: 1
    unauthorized :post, :seed_ecr, id: 1
  end

  as_a :admin do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :get, :edit, id: 1
    unauthorized :patch, :update, id: 1
    unauthorized :delete, :destroy, id: 1

    describe "#seed_ecr" do
      let(:secrets_url) { "http://foobar.server/api/v1/namespaces/foobar/secrets" }

      before do
        SamsonAwsEcr::Engine.expects(:refresh_credentials)
        DockerRegistry.first.username = 'user'
        DockerRegistry.first.password = 'pass'
      end

      it "creates missing credentials" do
        Kubernetes::Cluster.any_instance.expects(:namespaces).returns(['foobar'])
        stub_request(:get, "#{secrets_url}/kube-ecr-auth").to_return(status: 404)
        stub_request(:post, secrets_url).to_return(body: "{}")
        post :seed_ecr, params: {id: cluster.id}
        assert_redirected_to "/kubernetes/clusters"
      end

      it "updates existing credentials" do
        Kubernetes::Cluster.any_instance.expects(:namespaces).returns(['foobar'])
        stub_request(:get, "#{secrets_url}/kube-ecr-auth").to_return(body: "{}")
        stub_request(:put, "#{secrets_url}/kube-ecr-auth").to_return(body: "{}")
        post :seed_ecr, params: {id: cluster.id}
        assert_redirected_to "/kubernetes/clusters"
      end
    end
  end

  as_a :super_admin do
    describe "#new" do
      use_example_config

      it "renders" do
        get :new
        assert_template :edit
        assigns(:cluster).config_filepath.must_include Dir.tmpdir
      end

      it "renders when ECR plugin is active" do
        SamsonAwsEcr::Engine.expects(:active?).returns(true)
        get :new
        assert_template :edit
      end

      it "can prefill config_filepath" do
        Kubernetes::Cluster.any_instance.expects(:kubeconfig).returns(stub(contexts: []))
        get :new, params: {kubernetes_cluster: {config_filepath: "foo"}}
        assigns(:cluster).config_filepath.must_equal "foo"
      end

      describe "when config file env is not set" do
        with_env KUBE_CONFIG_FILE: nil

        it "uses last config" do
          get :new
          assert_template :edit
          assigns(:cluster).config_filepath.must_equal "plugins/kubernetes/test/cluster_config.yml"
        end

        it "can render without any config file" do
          Kubernetes::Cluster.delete_all
          get :new
          assert_template :edit
          assigns(:cluster).config_filepath.must_equal nil
        end
      end
    end

    describe "#create" do
      use_example_config
      let(:params) do
        {config_filepath: ENV.fetch("KUBE_CONFIG_FILE"), config_context: 'default', name: 'foobar', ip_prefix: '1.2'}
      end

      before { Kubernetes::Cluster.any_instance.stubs(connection_valid?: true) } # avoid real connection

      it "redirects on success" do
        post :create, params: {kubernetes_cluster: params}
        assert_redirected_to "http://test.host/kubernetes/clusters/#{Kubernetes::Cluster.last.id}"
      end

      it "renders when it fails to create" do
        params.delete(:name)
        post :create, params: {kubernetes_cluster: params}
        assert_template :edit
      end
    end

    describe "#edit" do
      use_example_config

      it "renders" do
        get :edit, params: {id: cluster.id}
        assert_template :edit
      end
    end

    describe "#update" do
      use_example_config

      it "updates" do
        patch :update, params: {id: cluster.id, kubernetes_cluster: {name: "NEW"}}
        assert_redirected_to "/kubernetes/clusters"
        cluster.reload.name.must_equal "NEW"
      end

      it "shows errors when it fails to update" do
        patch :update, params: {id: cluster.id, kubernetes_cluster: {name: ""}}
        assert_template :edit
      end
    end

    describe "#destroy" do
      it "destroys" do
        cluster
        assert_difference 'Kubernetes::Cluster.count', -1 do
          delete :destroy, params: {id: cluster.id}
          assert_redirected_to "/kubernetes/clusters"
        end
      end

      it "renders when it fails to destroy" do
        # cluster still has usages, cannot destroy
        Kubernetes::ClusterDeployGroup.any_instance.stubs(:validate_namespace_exists)
        cluster.cluster_deploy_groups.create! deploy_group: deploy_groups(:pod100), namespace: 'foo'

        delete :destroy, params: {id: cluster.id}
        assert_template :edit
      end
    end
  end
end
