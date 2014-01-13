require_relative '../../test_helper'

describe Admin::CommandsController do
  as_a_admin do
    describe 'GET to #index' do
      before { get :index }

      it 'renders template' do
        assert_template :index
      end
    end

    describe 'GET to #new' do
      before { get :new }

      it 'renders template' do
        assert_template :new
      end
    end

    describe 'POST to #create' do
      before do
        post :create, :command => attributes
      end

      describe 'invalid' do
        let(:attributes) {{ :command => nil }}

        it 'renders and sets the flash' do
          flash[:error].wont_be_nil
          assert_template :new
        end
      end

      describe 'valid' do
        let(:attributes) {{ :command => 'echo hi' }}

        it 'redirects and sets the flash' do
          flash[:notice].wont_be_nil
          assert_redirected_to admin_commands_path
        end
      end
    end

    describe 'GET to #edit' do
      describe 'invalid command' do
        before { get :edit, id: 123123 }

        it 'redirects' do
          assert_redirected_to admin_commands_path
        end
      end

      describe 'valid command' do
        before { get :edit, id: commands(:echo).id }

        it 'renders the template' do
          assert_template :edit
        end
      end
    end

    describe 'PUT to #update' do
      before do
        put :update, :id => commands(:echo).id,
          :command => attributes
      end

      describe 'invalid' do
        let(:attributes) {{ :command => nil }}

        it 'renders and sets the flash' do
          flash[:error].wont_be_nil
          assert_template :edit
        end
      end

      describe 'valid' do
        let(:attributes) {{ :command => 'echo hi' }}

        it 'redirects and sets the flash' do
          flash[:notice].wont_be_nil
          assert_redirected_to admin_commands_path
        end
      end
    end

    describe 'DELETE to #destroy' do
      describe 'invalid' do
        before { delete :destroy, :id => 123123 }

        it 'redirects' do
          assert_redirected_to admin_commands_path
        end
      end

      describe 'valid' do
        before { delete :destroy, :id => commands(:echo).id }

        it 'redirects' do
          flash[:notice].wont_be_nil
          assert_redirected_to admin_commands_path
        end

        it 'removes the command' do
          Command.exists?(commands(:echo).id).must_equal(false)
        end
      end
    end
  end
end
