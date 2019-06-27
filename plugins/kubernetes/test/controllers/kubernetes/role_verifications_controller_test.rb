# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::RoleVerificationsController do
  as_a :viewer do
    describe '#new' do
      it "renders" do
        get :new
        assert_template :new
      end
    end

    describe '#create' do
      it "succeeds when valid" do
        Kubernetes::RoleValidator.any_instance.expects(:validate).returns nil
        post :create, params: {role: {}.to_json}
        assert flash.now[:notice], assigns[:errors]
        assert_template :new
      end

      it "fails when invalid" do
        post :create, params: {role: {}.to_json}
        assert assigns[:errors]
        assert_template :new
      end

      it "fails nicely with borked template" do
        post :create, params: {role: "---"}
        assigns[:errors].must_include "Error found when validating test.yml"
      end

      it "reports invalid json" do
        post :create, params: {role: "{oops"}
        assigns[:errors].must_include "Error found when parsing test.json"
      end

      it "reports invalid yaml" do
        post :create, params: {role: "}foobar:::::"}
        assigns[:errors].must_include "Error found when parsing test.yml"
      end
    end
  end
end
