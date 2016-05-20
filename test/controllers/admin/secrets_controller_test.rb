require_relative '../../test_helper'

SingleCov.covered!

describe Admin::SecretsController do
  def create_global
    create_secret 'production/global/pod2/foo'
  end

  let(:secret) { create_secret 'production/foo/pod2/some_key' }
  let(:other_project) do
    Project.any_instance.stubs(:valid_repository_url).returns(true)
    Project.create!(name: 'Z', repository_url: 'Z')
  end

  as_a_viewer do
    unauthorized :get, :index
    unauthorized :get, :new
  end

  as_a_deployer do
    unauthorized :post, :create, secret: {
      environment_permalink: 'production',
      project_permalink: 'foo',
      deploy_group_permalink: 'group',
      key: 'bar'
    }

    describe '#index' do
      it 'renders template without secret values' do
        create_global
        get :index
        assert_template :index
        assigns[:secret_keys].size.must_equal 1
        response.body.wont_include secret.value
      end
    end

    describe "#new" do
      it "renders" do
        get :new
        assert_template :edit
      end
    end

    describe '#edit' do
      it "is unauthrized" do
        get :edit, id: secret
        assert_unauthorized
      end
    end

    describe '#update' do
      it "is unauthrized" do
        put :update, id: secret, secret: {value: 'xxx'}
        assert_unauthorized
      end
    end

    describe "#destroy" do
      it "is unauthorized" do
        delete :destroy, id: secret.id
        assert_unauthorized
      end
    end
  end

  as_a_project_admin do
    describe '#create' do
      let(:attributes) do
        {
          environment_permalink: 'production',
          project_permalink: 'foo',
          deploy_group_permalink: 'pod2',
          key: 'v',
          value: 'echo hi'
        }
      end

      before { post :create, secret: attributes }

      it 'creates a secret' do
        flash[:notice].wont_be_nil
        assert_redirected_to admin_secrets_path
        secret = SecretStorage::DbBackend::Secret.find('production/foo/pod2/v')
        secret.updater_id.must_equal user.id
        secret.creator_id.must_equal user.id
      end

      describe 'invalid' do
        let(:attributes) do
          {
            environment_permalink: 'production',
            project_permalink: 'foo',
            deploy_group_permalink: 'group',
            key: '',
            value: ''
          }
        end

        it 'renders and sets the flash' do
          assert flash[:error]
          assert_template :edit
        end
      end

      describe 'global' do
        let(:attributes) do
          {
            environment_permalink: 'production',
            project_permalink: 'global',
            deploy_group_permalink: 'somegroup',
            key: 'bar'
          }
        end

        it 'is unauthorized' do
          assert_unauthorized
        end
      end
    end

    describe '#edit' do
      it 'renders for local secret as project-admin' do
        get :edit, id: secret
        assert_template :edit
        response.body.wont_include secret.value
      end

      it 'renders with unfound users' do
        secret.update_column(:updater_id, 32232323)
        get :edit, id: secret
        assert_template :edit
        response.body.must_include "Unknown user id"
      end

      it "is unauthrized for global secret" do
        get :edit, id: create_global
        assert_unauthorized
      end
    end

    describe '#update' do
      let(:attributes) { { value: 'hi' } }

      before do
        patch :update, id: secret.id, secret: attributes
      end

      it 'updates' do
        flash[:notice].wont_be_nil
        assert_redirected_to admin_secrets_path
        secret.reload
        secret.updater_id.must_equal user.id
        secret.creator_id.must_equal users(:admin).id
      end

      describe 'invalid' do
        let(:attributes) { { value: '' } }

        it 'fails to update' do
          assert_template :edit
          assert flash[:error]
        end
      end

      describe 'updating key' do
        let(:attributes) do
          {value: 'hi', project_permalink: other_project.permalink, key: 'bar'}
        end

        it "is not supported" do
          assert_redirected_to admin_secrets_path
          secret.reload.id.must_equal 'production/foo/pod2/some_key'
        end
      end

      describe 'editing a not owned project' do
        let(:secret) { create_secret "production/#{other_project.permalink}/foo/xxx" }

        it "is not allowed" do
          assert_unauthorized
        end
      end

      describe 'global' do
        let(:secret) { create_global }

        it "is unauthrized" do
          assert_unauthorized
        end
      end
    end

    describe "#destroy" do
      it "deletes project secret" do
        delete :destroy, id: secret
        assert_redirected_to admin_secrets_path
      end

      it "is unauthorized for global" do
        delete :destroy, id: create_global
        assert_unauthorized
      end
    end
  end

  as_a_admin do
    let(:secret) { create_global }
    describe '#create' do
      let(:attributes) do
        {
          environment_permalink: 'production',
          project_permalink: 'foo',
          deploy_group_permalink: 'pod2',
          key: 'v',
          value: 'echo hi'
        }
      end

      before do
        post :create, secret: attributes
      end

      it 'redirects and sets the flash' do
        flash[:notice].wont_be_nil
        assert_redirected_to admin_secrets_path
      end
    end

    describe '#edit' do
      it "renders" do
        get :edit, id: secret.id
        assert_template :edit
      end

      it "renders with unknown project" do
        secret.update_column(:id, 'oops/bar')
        get :edit, id: secret.id
        assert_template :edit
      end
    end

    describe '#update' do
      it "updates" do
        put :update, id: secret, secret: {
          environment_permalink: 'production',
          project_permalink: 'foo',
          deploy_group_permalink: 'pod2',
          key: 'hi',
          value: 'secret'
        }
        assert_redirected_to admin_secrets_path
      end
    end

    describe '#destroy' do
      it 'deletes and redirects' do
        delete :destroy, id: secret.id
        flash[:notice].wont_be_nil
        assert_redirected_to admin_secrets_path
        SecretStorage::DbBackend::Secret.exists?(secret.id).must_equal(false)
      end

      it "works with unknown project" do
        secret.update_column(:id, 'oops/bar')
        delete :destroy, id: secret.id
        flash[:notice].wont_be_nil
        assert_redirected_to admin_secrets_path
        SecretStorage::DbBackend::Secret.exists?(secret.id).must_equal(false)
      end
    end
  end
end
