require_relative '../../../test_helper'

SingleCov.covered! uncovered: 11

describe Admin::Kubernetes::ClustersController do
  def self.use_example_config
    around { |t| with_example_kube_config { |f| with_env "KUBE_CONFIG_FILE": f, &t } }
  end

  let(:cluster) { create_kubernetes_cluster }

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :get, :edit, id: 1
  end

  as_a_admin do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :get, :edit, id: 1

    describe "#index" do
      it "renders" do
        get :index
        assert_template :index
      end
    end
  end

  as_a_super_admin do
    describe "#new" do
      use_example_config

      it "renders" do
        get :new
        assert_template :new
      end
    end

    describe "#create" do
      use_example_config
      let(:params) { {config_filepath: __FILE__, config_context: 'y', name: 'foobar'} }

      before { Kubernetes::Cluster.any_instance.stubs(connection_valid?: true) }  # avoid real connection

      it "redirects on success" do
        Kubernetes::Cluster.any_instance.expects(:watch!) # spawn threads
        post :create, kubernetes_cluster: params
        assert_redirected_to "http://test.host/admin/kubernetes/clusters/#{Kubernetes::Cluster.last.id}"
      end

      it "renders when it fails to create" do
        params.delete(:name)
        Kubernetes::Cluster.any_instance.expects(:watch!).never
        post :create, kubernetes_cluster: params
        assert_template :new
      end
    end

    describe "#edit" do
      use_example_config

      it "renders" do
        get :edit, id: cluster.id
        assert_template :edit
      end
    end

    describe "#load_default_config_file" do
      it "blows up when not configured" do
        get :new
        assert_response :bad_request
      end

      it "works with an existing config file" do
        with_example_kube_config do |f|
          with_env "KUBE_CONFIG_FILE": f do
            get :new
            assert_template :new
          end
        end
      end

      it "blows up with missing config file" do
        with_env "KUBE_CONFIG_FILE": "nope" do
          assert_raises ArgumentError do
            get :new
          end
        end
      end
    end
  end
end
