# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe UserProjectRolesController do
  let(:project) { projects(:test) }

  as_a :viewer do
    describe "#index" do
      it 'renders' do
        get :index, params: {project_id: project.to_param}
        assert_template :index
        assigns(:users).size.must_equal User.count
      end

      it 'renders JSON' do
        get :index, params: {project_id: project.to_param, format: 'json'}
        users = JSON.parse(response.body).fetch('users')
        users.size.must_equal User.count
      end

      it 'filters' do
        get :index, params: {project_id: project.to_param, search: "Admin"}
        assert_template :index
        users = assigns(:users).sort_by(&:name)
        users.map(&:name).sort.must_equal ["Admin", "Deployer Project Admin", "Super Admin"]
        users.first.user_project_role_id.must_equal nil
      end

      it 'filters by role' do
        get :index, params: {project_id: project.to_param, role_id: Role::ADMIN.id}
        assert_template :index
        assigns(:users).map(&:name).sort.must_equal ["Admin", "Deployer Project Admin", "Super Admin"]
      end

      it 'filters by project role' do
        role = UserProjectRole.create!(role_id: Role::ADMIN.id, project: projects(:test), user: users(:deployer))
        get :index, params: {project_id: project.to_param, role_id: Role::ADMIN.id}
        assert_template :index
        assigns(:users).map(&:name).sort.must_equal ["Admin", "Deployer", "Deployer Project Admin", "Super Admin"]
        assigns(:users).map(&:user_project_role_id).must_include role.role_id
      end
    end
  end

  as_a :deployer do
    unauthorized :post, :create, project_id: :foo
  end

  as_a :project_admin do
    describe "#create" do
      def create(role_id, **options)
        post :create, params: {project_id: project, user_id: new_admin.id, role_id: role_id}, **options
      end

      let(:new_admin) { users(:deployer) }

      it 'creates new project role' do
        create Role::ADMIN.id
        assert_response :redirect
        role = new_admin.user_project_roles.first
        role.role_id.must_equal Role::ADMIN.id
      end

      it 'updates existing role' do
        new_admin.user_project_roles.create!(role_id: Role::DEPLOYER.id, project: project)
        create Role::ADMIN.id
        assert_response :redirect
        role = new_admin.user_project_roles.first.reload
        role.role_id.must_equal Role::ADMIN.id
      end

      it 'deletes existing role when setting to None' do
        new_admin.user_project_roles.create!(role_id: Role::DEPLOYER.id, project: project)
        create ''
        assert_response :redirect
        refute new_admin.reload.user_project_roles.first
      end

      it 'does nothing when setting from None to None' do
        create ''
        assert_response :redirect
        refute new_admin.user_project_roles.first
      end

      it 'clears the access request pending flag' do
        check_pending_request_flag(new_admin) do
          create Role::ADMIN.id
          assert_response :redirect
        end
      end

      it 'renders text for xhr requests' do
        create Role::ADMIN.id, xhr: true
        assert_response :success
      end
    end
  end

  private

  def check_pending_request_flag(user)
    user.update!(access_request_pending: true)
    assert(user.access_request_pending)
    yield
    user.reload
    refute(user.access_request_pending)
  end
end
