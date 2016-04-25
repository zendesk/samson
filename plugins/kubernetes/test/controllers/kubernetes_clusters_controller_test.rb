require_relative '../test_helper'

SingleCov.covered! uncovered: 23

describe KubernetesClustersController do
  as_a_deployer do
    unauthorized :get, :new
  end

  as_a_admin do
    unauthorized :get, :new
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
  end
end
