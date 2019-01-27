# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe VaultServersController do
  let!(:server) { create_vault_server }
  before { deploy_groups(:pod1).update_column(:vault_server_id, server.id) }

  as_a :viewer do
    describe "#index" do
      it "renders" do
        get :index
        assert_response :success
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: server.id}
        assert_response :success
        response.body.wont_include server.token
      end
    end

    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :post, :sync, id: 1
    unauthorized :patch, :update, id: 1
    unauthorized :delete, :destroy, id: 1
  end

  as_a :super_admin do
    describe "#new" do
      it "renders" do
        get :new
        assert_response :success
      end
    end

    describe "#create" do
      let(:valid_params) { {name: 'pod2', address: 'http://vault-land.com', token: 'TOKEN2'} }

      it "creates" do
        assert_difference 'Samson::Secrets::VaultServer.count', +1 do
          post :create, params: {vault_server: valid_params}
        end
        assert flash[:notice]
        assert_redirected_to action: :index
      end

      it "fails" do
        refute_difference 'Samson::Secrets::VaultServer.count' do
          valid_params[:name] = server.name
          post :create, params: {vault_server: valid_params}
        end
        assert_response :success # renders edit
      end
    end

    describe "#sync" do
      it "syncs" do
        other = Samson::Secrets::VaultServer.create!(name: 'pod2', address: 'http://vault-land.com', token: 'TOKEN2')
        Samson::Secrets::VaultServer.any_instance.expects(:sync!).with(other).returns([1, 2, 3])

        post :sync, params: {id: server.id, other_id: other.id}

        assert_redirected_to vault_server_path(server)
        flash[:notice].must_equal "Synced 3 values!"
      end
    end

    describe "#update" do
      it "updates" do
        patch :update, params: {id: server, vault_server: {name: 'xyz'}}
        assert flash[:notice]
        assert_redirected_to action: :index
      end

      it "fails" do
        patch :update, params: {id: server, vault_server: {name: ''}}
        assert_response :success # renders edit
      end
    end

    describe "#destroy" do
      it "destroys" do
        assert_difference 'Samson::Secrets::VaultServer.count', -1 do
          delete :destroy, params: {id: server.id}
        end
        assert flash[:notice]
        assert_redirected_to action: :index
      end
    end
  end
end
