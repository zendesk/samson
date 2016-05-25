require_relative '../../test_helper'

SingleCov.covered!

describe Admin::CommandsController do
  as_a_deployer do
    unauthorized :get, :index
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 123123

    describe 'GET to #edit' do
      it "is unauthrized" do
        get :edit, id: commands(:echo)
        assert_unauthorized
      end
    end

    describe 'PUT to #update' do
      it "is unauthrized" do
        put :update, id: commands(:echo)
        assert_unauthorized
      end
    end
  end

  as_a_project_admin do
    unauthorized :get, :index
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 123123

    describe 'GET to #edit' do
      it 'renders for local command as project-admin' do
        get :edit, id: commands(:echo).id
        assert_template :edit
      end

      it "is unauthrized for global commands" do
        get :edit, id: commands(:global)
        assert_unauthorized
      end
    end

    describe 'PATCH to #update' do
      let(:command) { commands(:echo) }
      let(:attributes) { { command: 'echo hi' } }
      let(:format) { 'html' }

      before do
        patch :update, id: command.id, command: attributes, format: format
      end

      describe 'valid' do
        describe 'html' do
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

      describe 'invalid' do
        let(:attributes) { { command: nil } }

        describe 'html' do
          it 'renders' do
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

      describe 'global' do
        let(:command) { commands(:global) }

        it "is unauthrized" do
          assert_unauthorized
        end
      end
    end
  end

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
        let(:attributes) { { command: nil } }

        it 'renders' do
          assert_template :edit
        end
      end

      describe 'valid' do
        let(:attributes) { { command: 'echo hi' } }

        it 'redirects and sets the flash' do
          flash[:notice].wont_be_nil
          assert_redirected_to admin_commands_path
        end
      end
    end

    describe 'GET to #edit' do
      it "renders for global commands" do
        get :edit, id: commands(:global).id
        assert_template :edit
      end
    end

    describe 'PUT to #update' do
      it "updates a global commands" do
        put :update, id: commands(:global).id, command: { command: 'echo hi' }
        assert_redirected_to admin_commands_path
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
end
