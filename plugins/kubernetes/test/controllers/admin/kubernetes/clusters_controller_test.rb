require_relative '../../../test_helper'

SingleCov.covered! uncovered: 21

describe Admin::Kubernetes::ClustersController do
  let(:cluster) { create_kubernetes_cluster }

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :get, :new
    unauthorized :get, :edit, id: 1
  end

  as_a_admin do
    unauthorized :get, :new
    unauthorized :get, :edit, id: 1

    describe "#index" do
      around { |t| with_example_kube_config { |f| with_env "KUBE_CONFIG_FILE": f, &t } }

      it "renders" do
        get :index
        assert_template :index
      end
    end
  end

  as_a_super_admin do
    describe "#new" do
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

    describe "#edit" do
      around { |t| with_example_kube_config { |f| with_env "KUBE_CONFIG_FILE": f, &t } }

      it "renders" do
        get :edit, id: cluster.id
        assert_template :edit
      end
    end
  end
end
