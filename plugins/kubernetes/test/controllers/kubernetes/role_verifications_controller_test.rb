# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::RoleVerificationsController do
  as_a_viewer do
    describe '#new' do
      it "renders" do
        get :new
        assert_template :new
      end
    end

    describe '#create' do
      it "succeeds when valid" do
        Kubernetes::RoleVerifier.any_instance.expects(:verify).returns nil
        post :create, role: {}.to_json
        assert flash.now[:notice], assigns[:errors]
        assert_template :new
      end

      it "fails when invalid" do
        post :create, role: {}.to_json
        assert assigns[:errors]
        assert_template :new
      end

      it "fails nicely with borked template" do
        post :create, role: "---"
        assigns[:errors].must_include "Error found when parsing test.yml"
      end

      it "reports invalid json" do
        post :create, role: "{oops"
        assigns[:errors].must_include "Error found when parsing test.json"
      end

      it "reports invalid yaml" do
        post :create, role: "}foobar:::::"
        assigns[:errors].must_include "Error found when parsing test.yml"
      end
    end
  end
end
