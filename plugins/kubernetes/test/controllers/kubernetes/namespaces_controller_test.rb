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
  end

  as_a :deployer do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :patch, :update, id: 1
  end

  as_a :admin do
    describe "#new" do
      it "renders" do
        get :new
        assert_template :new
      end
    end

    describe "#create" do
      before { Kubernetes::Cluster.any_instance.stubs(connection_valid?: true) } # avoid real connection

      it "redirects on success" do
        post :create, params: {kubernetes_namespace: {name: "foo"}}
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
        assert_template :edit
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
  end
end
