require_relative '../../test_helper'

describe Admin::CommandsController do
  as_a_admin do
    describe 'GET to #index' do
      let(:echo) { commands(:echo) }
      let(:global) { commands(:global) }

      it 'renders template' do
        get :index
        assert_template :index
        assigns[:commands].sort_by(&:id).must_equal [global, echo].sort_by(&:id)
      end

      it 'can filter by words' do
        get :index, search: {query: 'echo'}
        assigns[:commands].must_equal [echo]
      end

      it 'can filter by project_id' do
        get :index, search: {project_id: echo.project_id}
        assigns[:commands].must_equal [echo]
      end

      it 'can filter by global' do
        get :index, search: {project_id: 'global'}
        assigns[:commands].must_equal [global]
      end
    end

    describe 'GET to #new' do
      before { get :new }

      it 'renders template' do
        assert_template :edit
      end
    end

    describe 'POST to #create' do
      before do
        post :create, command: attributes
      end

      describe 'invalid' do
        let(:attributes) {{ command: nil }}

        it 'renders and sets the flash' do
          flash[:error].wont_be_nil
          assert_template :edit
        end
      end

      describe 'valid' do
        let(:attributes) {{ command: 'echo hi' }}

        it 'redirects and sets the flash' do
          flash[:notice].wont_be_nil
          assert_redirected_to admin_commands_path
        end
      end
    end

    describe 'GET to #edit' do
      it "renders" do
        get :edit, id: commands(:echo).id
        assert_template :edit
      end

      it 'fails for non-existent command' do
        assert_raises ActiveRecord::RecordNotFound do
          get :edit, id: 123123
        end
      end
    end

    describe 'PATCH to #update' do
      before do
        patch :update, id: commands(:echo).id,
          command: attributes, format: format
      end

      describe 'invalid' do
        let(:attributes) {{ command: nil }}

        describe 'html' do
          let(:format) { 'html' }

          it 'renders and sets the flash' do
            flash[:error].wont_be_nil
            assert_template :edit
          end
        end

        describe 'json' do
          let(:format) { 'json' }

          it 'responds unprocessable' do
            assert_response :unprocessable_entity
          end
        end
      end

      describe 'valid' do
        let(:attributes) {{ command: 'echo hi' }}

        describe 'html' do
          let(:format) { 'html' }

          it 'redirects and sets the flash' do
            flash[:notice].wont_be_nil
            assert_redirected_to admin_commands_path
          end
        end

        describe 'json' do
          let(:format) { 'json' }

          it 'responds ok' do
            assert_response :ok
          end
        end
      end
    end

    describe 'DELETE to #destroy' do
      it "fails with unknown id" do
        assert_raises ActiveRecord::RecordNotFound do
          delete :destroy, id: 123123
        end
      end

      describe 'valid' do
        before { delete :destroy, id: commands(:echo).id, format: format }

        describe 'html' do
          let(:format) { 'html' }

          it 'redirects' do
            flash[:notice].wont_be_nil
            assert_redirected_to admin_commands_path
          end

          it 'removes the command' do
            Command.exists?(commands(:echo).id).must_equal(false)
          end
        end

        describe 'json' do
          let(:format) { 'json' }

          it 'responds ok' do
            assert_response :ok
          end
        end
      end
    end
  end

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 123123

    describe 'GET to #edit' do
      it 'does not render for global command' do
        get :edit, id: commands(:global).id
        @unauthorized.must_equal true, "Request was not marked unauthorized"
      end

      it 'renders for local command as project-admin' do
        UserProjectRole.create!(user: users(:deployer), project: projects(:test), role_id: ProjectRole::ADMIN.id)
        get :edit, id: commands(:echo).id
        assert_template :edit
      end

      it 'does not render for local command as non-project-admin' do
        get :edit, id: commands(:echo).id
        @unauthorized.must_equal true, "Request was not marked unauthorized"
      end
    end

    describe 'PATCH to #update' do
      let(:attributes) {{ command: 'echo hi' }}

      it 'does not update for global command' do
        patch :update, id: commands(:global).id, command: attributes, format: :json
        @unauthorized.must_equal true, "Request was not marked unauthorized"
      end

      it 'updates for local command as project-admin' do
        UserProjectRole.create!(user: users(:deployer), project: projects(:test), role_id: ProjectRole::ADMIN.id)
        patch :update, id: commands(:echo).id, command: attributes, format: :json
        assert_response :ok
      end

      it 'does not update for local command as non-project-admin' do
        patch :update, id: commands(:echo).id, command: attributes, format: :json
        @unauthorized.must_equal true, "Request was not marked unauthorized"
      end
    end
  end
end
