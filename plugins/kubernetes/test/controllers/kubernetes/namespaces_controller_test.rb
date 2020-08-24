# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::NamespacesController do
  let(:namespace) { kubernetes_namespaces(:test) }

  unauthorized :get, :index
  unauthorized :get, :show, id: 1

  as_a :viewer do
    describe "#index" do
      it "renders" do
        get :index
        assert_template :index
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: namespace.id}
        assert_template :show
      end
    end

    describe "#preview" do
      let(:template) do
        {
          apiVersion: "v1",
          kind: "Pod",
          metadata: {
            name: "test-app-server",
            labels: {
              team: "t",
              project: "p",
              role: "r"
            }
          },
          annotation: {"samson/keep_name": "false"}
        }.to_yaml
      end
      before do
        GitRepository.any_instance.stubs(:file_content).returns template
        # kubernetes_roles(:app_server).update_column(:resource_name, "foo")
        kubernetes_roles(:resque_worker).delete # 1 is enough
      end

      it "shows when there are no changes" do
        get :preview, params: {project_id: projects(:test).id}
        assert_redirected_to "/kubernetes/namespaces"
        assert flash[:notice]
      end

      it "warns when config file cannot be read" do
        GitRepository.any_instance.stubs(:file_content).returns nil
        get :preview, params: {project_id: projects(:test).id}
        flash[:alert].must_equal "<p>Unable to read kubernetes/app_server.yml</p>"
      end

      it "can validate against services" do
        raise unless template.sub!('Pod', 'Service')
        get :preview, params: {project_id: projects(:test).id}
        assert flash[:alert]
      end

      it "ignores immutable because their name cannot change" do
        raise unless template.sub!('Pod', 'APIService')
        get :preview, params: {project_id: projects(:test).id}
        assert flash[:notice]
      end

      it "shows when there are changes" do
        raise unless template.sub!('test-app-server', 'nope')
        get :preview, params: {project_id: projects(:test).id}
        flash[:alert].must_equal(
          "<p>Project config kubernetes/app_server.yml Pod nope would be duplicated with name test-app-server</p>"
        )
      end
    end
  end

  as_a :deployer do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :patch, :update, id: 1
    unauthorized :post, :sync_all
    unauthorized :post, :sync, id: 1
  end

  as_a :admin do
    let(:apply_url) { "http://foobar.server/api/v1/namespaces/test?fieldManager=samson&force=true" }

    describe "#new" do
      it "renders" do
        get :new
        assert_template :new
      end
    end

    describe "#create" do
      before { Kubernetes::Cluster.any_instance.stubs(connection_valid?: true) } # avoid real connection

      it "redirects on success" do
        @controller.expects(:create_callback)
        post :create, params: {kubernetes_namespace: {name: "foo", template: "metadata:\n  labels:\n    team: foo"}}
        namespace = Kubernetes::Namespace.find_by_name!("foo")
        assert_redirected_to "http://test.host/kubernetes/namespaces/#{namespace.id}"
      end

      it "renders when it fails to create" do
        post :create, params: {kubernetes_namespace: {name: ""}}
        assert_template :new
      end
    end

    describe "#update" do
      it "updates" do
        patch :update, params: {id: namespace.id, kubernetes_namespace: {comment: "new"}}
        assert_redirected_to namespace
        namespace.reload.comment.must_equal "new"
      end

      it "does not allow updating name" do
        assert_raises ActionController::UnpermittedParameters do
          patch :update, params: {id: namespace.id, kubernetes_namespace: {name: "new"}}
        end
      end

      it "shows errors when it fails to update" do
        Kubernetes::Namespace.any_instance.expects(:valid?).returns(false) # no validation that can fail
        patch :update, params: {id: namespace.id, kubernetes_namespace: {comment: ""}}
        assert_template :show
      end

      it "updates namespace when template was changed" do
        assert_request(:get, "http://foobar.server/api/v1/namespaces", to_return: {body: {items: []}.to_json}) do
          assert_request(:patch, apply_url, to_return: {body: '{}'}) do
            patch(
              :update,
              params: {id: namespace.id, kubernetes_namespace: {template: "metadata:\n  labels:\n    team: bar"}}
            )
          end
        end
        assert_redirected_to namespace
      end
    end

    describe "#destroy" do
      it "destroys" do
        namespace
        assert_difference 'Kubernetes::Namespace.count', -1 do
          delete :destroy, params: {id: namespace.id}
          assert_redirected_to "/kubernetes/namespaces"
        end
      end
    end

    describe "#sync" do
      it "syncs namespaces/clusters" do
        assert_request(:get, "http://foobar.server/api/v1/namespaces", to_return: {body: {items: []}.to_json}) do
          assert_request(:patch, apply_url, to_return: {body: '{}'}) do
            post :sync, params: {id: namespace.id}
          end
        end
        assert_redirected_to "http://test.host/kubernetes/namespaces/#{namespace.id}"
        refute flash[:warn]
      end
    end

    describe "#sync_all" do
      it "syncs namespaces/clusters" do
        assert_request(:get, "http://foobar.server/api/v1/namespaces", to_return: {body: {items: []}.to_json}) do
          assert_request(:patch, apply_url, to_return: {body: '{}'}) do
            post :sync_all
          end
        end
        assert_redirected_to "http://test.host/kubernetes/namespaces"
        refute flash[:warn]
      end

      it "shows errors" do
        assert_request(:get, "http://foobar.server/api/v1/namespaces", to_return: {body: {items: []}.to_json}) do
          assert_request(:patch, apply_url, to_return: {status: 404}) do
            post :sync_all
          end
        end
        assert_redirected_to "http://test.host/kubernetes/namespaces"
        flash[:warn].must_include "Failed to apply namespace test in cluster test: 404 Not Found"
      end
    end

    describe "#sync_namespace" do
      def expect_namespaces_request(&block)
        assert_request(
          :get,
          "http://foobar.server/api/v1/namespaces",
          to_return: {body: {items: existing}.to_json},
          &block
        )
      end

      let(:existing) do
        [
          {
            metadata: {
              name: "test",
              labels: {team: "foo", project: "bar"},
              annotations: {"samson/url": "http://www.test-url.com/kubernetes/namespaces/411008527"}
            }
          }
        ]
      end

      before { @controller.instance_variable_set(:@kubernetes_namespace, namespace) }

      it "creates a namespace" do
        existing.clear
        expect_namespaces_request do
          assert_request(:patch, apply_url, to_return: {body: '{}'}) do
            @controller.send(:create_callback)
          end
        end
        refute flash[:warn]
      end

      it "avoids work when nothing changed to allow efficient full cluster sync" do
        expect_namespaces_request do
          @controller.send(:create_callback)
        end
        refute flash[:warn]
      end

      it "updates when something was added" do
        existing[0][:metadata][:labels].delete :team
        expect_namespaces_request do
          assert_request(:patch, apply_url, to_return: {body: '{}'}) do
            @controller.send(:create_callback)
          end
        end
      end

      it "updates when something was changed" do
        existing[0][:metadata][:labels][:team] = "baz"
        expect_namespaces_request do
          assert_request(:patch, apply_url, to_return: {body: '{}'}) do
            @controller.send(:create_callback)
          end
        end
      end

      it "shows creation errors" do
        retries = SamsonKubernetes::API_RETRIES
        existing.clear
        expect_namespaces_request do
          assert_request(:patch, apply_url, to_timeout: [], times: retries + 1) do
            @controller.send(:create_callback)
          end
        end
        flash[:warn].must_equal <<~TEXT.rstrip
          <p>Error applying namespace in some clusters:
          <br />Failed to apply namespace test in cluster test: Timed out connecting to server</p>
        TEXT
      end
    end

    describe "#copy_secrets" do
      it "copies secrets" do
        stub_request(:get, "http://foobar.server/api/v1/namespaces/f/secrets/s").to_return(body: {metadata: {}}.to_json)
        stub_request(:post, "http://foobar.server/api/v1/namespaces/t/secrets").to_return(body: '{}')
        @controller.send(:copy_secrets, ["s"], from: "f", to: "t").must_equal []
      end

      it "shows errors" do
        stub_request(:get, "http://foobar.server/api/v1/namespaces/f/secrets/s").to_return(status: 404)
        @controller.send(:copy_secrets, ["s"], from: "f", to: "t").must_equal(
          ["Failed to copy secret s to t in cluster test: 404 Not Found"]
        )
      end
    end
  end
end
