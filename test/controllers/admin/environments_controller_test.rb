require_relative '../../test_helper'

describe Admin::EnvironmentsController do
  def self.it_renders_index
    it 'get :index succeeds' do
      get :index
      assert_response :success
      assert_select('tbody tr').count.must_equal Environment.count
    end
  end

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
  end

  as_a_admin do
    it_renders_index
    unauthorized :post, :create
    unauthorized :get, :new
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :put, :update, id: 1
  end

  as_a_super_admin do
    it_renders_index

    it 'get :new succeeds' do
      get :new
      assert_response :success
      assert assigns(:environment)
    end

    describe '#create' do
      it 'creates an environment' do
        assert_difference 'Environment.count', +1 do
          post :create, environment: {name: 'gamma', is_production: true}
          assert_redirected_to admin_environments_path
        end
      end

      it 'should not create an environment with blank name' do
        env_count = Environment.count
        post :create, environment: {name: nil, is_production: true}
        assert_template :edit
        flash[:error].must_equal ["Permalink can't be blank", "Name can't be blank"]
        Environment.count.must_equal env_count
      end
    end

    describe '#delete' do
      it 'succeeds' do
        env = environments(:production)
        delete :destroy, id: env
        assert_redirected_to admin_environments_path
        Environment.where(id: env.id).must_equal []
      end

      it 'fail for non-existent environment' do
        assert_raises(ActiveRecord::RecordNotFound) do
          delete :destroy, id: -1
        end
      end
    end

    describe '#update' do
      let(:environment){ environments(:production) }

      before { request.env["HTTP_REFERER"] = admin_environments_url }

      it 'save' do
        post :update, environment: {name: 'Test Update', is_production: false}, id: environment
        assert_redirected_to admin_environments_path
        Environment.find(environment.id).name.must_equal 'Test Update'
      end

      it 'fail to edit with blank name' do
        post :update, environment: {name: '', is_production: false}, id: environment
        assert_template :edit
        flash[:error].must_equal ["Name can't be blank"]
        Environment.find(environment.id).name.must_equal 'Production'
      end
    end
  end
end
