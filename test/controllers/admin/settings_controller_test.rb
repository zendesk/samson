# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Admin::SettingsController do
  let!(:setting) { Setting.create!(name: 'FOO', value: 'BAR') }

  as_a_viewer do
    describe "#index" do
      it "renders" do
        get :index
        assert_response :success
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: setting.id}
        assert_response :success
      end
    end

    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :patch, :update, id: 1
    unauthorized :delete, :destroy, id: 1
  end

  as_a_super_admin do
    describe "#new" do
      it "renders" do
        get :new
        assert_response :success
      end
    end

    describe "#create" do
      let(:valid_params) { {name: 'FOO2', value: 'BAR'} }

      it "creates" do
        assert_difference 'Setting.count', +1 do
          post :create, params: {setting: valid_params}
        end
        assert flash[:notice]
        assert_redirected_to action: :index
      end

      it "fails" do
        refute_difference 'Setting.count' do
          valid_params[:name] = 'aaa'
          post :create, params: {setting: valid_params}
        end
        assert_response :success # renders edit
      end
    end

    describe "#update" do
      it "updates" do
        patch :update, params: {id: setting, setting: {name: 'XYZ'}}
        assert flash[:notice]
        assert_redirected_to action: :index
      end

      it "fails" do
        patch :update, params: {id: setting, setting: {name: ''}}
        assert_response :success # renders edit
      end
    end

    describe "#destroy" do
      it "destroys" do
        assert_difference 'Setting.count', -1 do
          delete :destroy, params: {id: setting.id}
        end
        assert flash[:notice]
        assert_redirected_to action: :index
      end
    end
  end
end
