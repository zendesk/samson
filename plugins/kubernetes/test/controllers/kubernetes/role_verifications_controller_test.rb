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
    end
  end
end
