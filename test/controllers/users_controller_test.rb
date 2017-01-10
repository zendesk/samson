# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe UsersController do
  let(:project) { projects(:test) }

  as_a_viewer do
    unauthorized :get, :index, project_id: :foo
  end

  as_a_deployer do
    unauthorized :get, :index, project_id: :foo
  end

  as_a_project_admin do
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
        assigns(:users).map(&:name).sort.must_equal ["Admin", "Deployer Project Admin", "Super Admin"]
        assigns(:users).first.user_project_role_id.must_equal nil
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
end
