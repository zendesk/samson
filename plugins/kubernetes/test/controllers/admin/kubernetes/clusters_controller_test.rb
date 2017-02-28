# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Admin::Kubernetes::ClustersController do
  def self.use_example_config
    around { |t| with_example_kube_config { |f| with_env "KUBE_CONFIG_FILE": f, &t } }
  end

  let(:cluster) { create_kubernetes_cluster }

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :get, :show, id: 1
    unauthorized :get, :edit, id: 1
    unauthorized :patch, :update, id: 1
    unauthorized :post, :seed_ecr, id: 1
  end

  as_a_admin do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :get, :edit, id: 1
    unauthorized :patch, :update, id: 1

    describe "#index" do
      it "renders" do
        get :index
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
        assert_redirected_to "/admin/kubernetes/clusters"
      end

      it "updates existing credentials" do
        Kubernetes::Cluster.any_instance.expects(:namespaces).returns(['foobar'])
        stub_request(:get, "#{secrets_url}/kube-ecr-auth").to_return(body: "{}")
        stub_request(:put, "#{secrets_url}/kube-ecr-auth").to_return(body: "{}")
        post :seed_ecr, params: {id: cluster.id}
        assert_redirected_to "/admin/kubernetes/clusters"
      end
    end
  end

  as_a_super_admin do
    describe "#new" do
      use_example_config

      it "renders" do
        get :new
        assert_template :edit
      end

      it "renders when ECR plugin is active" do
        SamsonAwsEcr::Engine.expects(:active?).returns(true)
        get :new
        assert_template :edit
      end
    end

    describe "#create" do
      use_example_config
      let(:params) { {config_filepath: __FILE__, config_context: 'y', name: 'foobar', ip_prefix: '1.2'} }

      before { Kubernetes::Cluster.any_instance.stubs(connection_valid?: true) } # avoid real connection

      it "redirects on success" do
        post :create, params: {kubernetes_cluster: params}
        assert_redirected_to "http://test.host/admin/kubernetes/clusters/#{Kubernetes::Cluster.last.id}"
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
        assert_redirected_to "/admin/kubernetes/clusters"
        cluster.reload.name.must_equal "NEW"
      end

      it "shows errors when it fails to update" do
        patch :update, params: {id: cluster.id, kubernetes_cluster: {name: ""}}
        assert_template :edit
      end
    end

    describe "#load_default_config_file" do
      before { ::Kubernetes::Cluster.destroy_all }

      it "works even without an ENV var or old cluster" do
        get :new
        assert_template :edit
        assigns['context_options'].must_be_empty
      end

      it "works with an existing config file from ENV" do
        with_example_kube_config do |f|
          with_env KUBE_CONFIG_FILE: f do
            get :new
            assert_template :edit
            assigns['context_options'].wont_be_empty
          end
        end
      end

      it "uses the config file from latest cluster" do
        with_example_kube_config do |f|
          create_kubernetes_cluster(config_filepath: f)
          get :new
          assert_template :edit
          assigns['context_options'].wont_be_empty
        end
      end

      it "uses the config file from current cluster" do
        cluster
        bad = create_kubernetes_cluster(name: 'bad')
        bad.update_column(:config_filepath, 'bad')
        get :edit, params: {id: cluster.id}
        assert_template :edit
        assigns['context_options'].wont_be_empty
      end

      it "blows up with missing config file" do
        with_env KUBE_CONFIG_FILE: "nope" do
          assert_raises(Errno::ENOENT) { get :new }
        end
      end
    end
  end
end
