require 'test_helper'

describe ProjectRolesController do
  let(:project) { projects(:test) }

  describe "a GET to #index" do
    as_a_viewer do
      it 'responds successfully' do
        get :index, format: 'json'
        roles = ProjectRole.all
        result = JSON.parse(response.body)
        result.wont_be_nil
        result.wont_be_empty
        result.length.must_equal roles.size
        result.each  do | role |
          role_info = ProjectRole.find(role['id'])
          role_info.wont_be_nil
        end
      end
    end
  end

  describe "a POST to #create" do
    as_a_viewer do
      unauthorized :post, :create, project_id: :foo
    end

    as_a_deployer do
      unauthorized :post, :create, project_id: :foo
    end

    as_a_admin do
      let(:new_admin) { users(:deployer) }

      it 'creates new project role' do
        post :create, project_id: project.id, project_role: { user_id: new_admin.id, project_id: project.id, role_id: ProjectRole::ADMIN.id }, format: 'json'

        assert_response :created

        user_project_roles = User.find(new_admin.id).user_project_roles
        user_project_roles.wont_be_empty
        user_project_role = user_project_roles.first
        user_project_role.role_id.must_equal ProjectRole::ADMIN.id

        result = JSON.parse(response.body)
        result.wont_be_nil
        result['id'].wont_be_nil
        result['id'].must_equal user_project_role.id
        result['user_id'].must_equal user_project_role.user_id
        result['project_id'].must_equal user_project_role.project_id
        result['role_id'].must_equal user_project_role.role_id
      end

      it 'fails to create new project role' do
        post :create, project_id: project.id, project_role: { user_id: new_admin.id, project_id: project.id, role_id: 3 }, format: 'json'

        assert_response :bad_request

        user_project_roles = User.find(new_admin.id).user_project_roles
        user_project_roles.must_be_empty

        result = JSON.parse(response.body)
        result['errors'].wont_be_nil
      end
    end

    as_a_project_admin do
      let(:new_admin) { users(:deployer) }

      it 'creates new project role' do
        post :create, project_id: project.id, project_role: { user_id: new_admin.id, project_id: project.id, role_id: ProjectRole::ADMIN.id }, format: 'json'

        assert_response :created

        user_project_roles = User.find(new_admin.id).user_project_roles
        user_project_roles.wont_be_empty
        user_project_role = user_project_roles.first
        user_project_role.role_id.must_equal ProjectRole::ADMIN.id

        result = JSON.parse(response.body)
        result.wont_be_nil
        result['id'].wont_be_nil
        result['id'].must_equal user_project_role.id
        result['user_id'].must_equal user_project_role.user_id
        result['project_id'].must_equal user_project_role.project_id
        result['role_id'].must_equal user_project_role.role_id
      end

      it 'fails to create new project role' do
        post :create, project_id: project.id, project_role: { user_id: new_admin.id, project_id: project.id, role_id: 3 }, format: 'json'

        assert_response :bad_request

        user_project_roles = User.find(new_admin.id).user_project_roles
        user_project_roles.must_be_empty

        result = JSON.parse(response.body)
        result['errors'].wont_be_nil
      end
    end
  end

  describe "a PUT to #update" do
    let(:current_project_admin) { users(:project_admin) }
    let(:current_project_admin_role) { user_project_roles(:project_admin) }

    as_a_viewer do
      unauthorized :put, :update, id: 1, project_id: :foo
    end

    as_a_deployer do
      unauthorized :put, :update, id: 1, project_id: :foo
    end

    as_a_admin do
      it 'updates the project role' do
        put :update, project_id: project.id, id: current_project_admin_role.id, project_role: { role_id: ProjectRole::DEPLOYER.id }, format: 'json'

        assert_response :success

        user_project_role = UserProjectRole.find(current_project_admin_role.id)
        user_project_role.wont_be_nil
        user_project_role.role_id.must_equal ProjectRole::DEPLOYER.id

        result = JSON.parse(response.body)
        result.wont_be_nil
        result['id'].wont_be_nil
        result['id'].must_equal user_project_role.id
        result['user_id'].must_equal user_project_role.user_id
        result['project_id'].must_equal user_project_role.project_id
        result['role_id'].must_equal user_project_role.role_id
      end

      it 'fails to update project role' do
        put :update, project_id: project.id, id: current_project_admin_role.id, project_role: { role_id: 3 }, format: 'json'

        assert_response :bad_request

        user_project_role = UserProjectRole.find(current_project_admin_role.id)
        user_project_role.wont_be_nil
        user_project_role.role_id.must_equal ProjectRole::ADMIN.id

        result = JSON.parse(response.body)
        result['errors'].wont_be_nil
      end
    end

    as_a_project_admin do
      it 'updates the project role' do
        put :update, project_id: project.id, id: current_project_admin_role.id, project_role: { role_id: ProjectRole::DEPLOYER.id }, format: 'json'

        assert_response :success

        user_project_role = UserProjectRole.find(current_project_admin_role.id)
        user_project_role.wont_be_nil
        user_project_role.role_id.must_equal ProjectRole::DEPLOYER.id

        result = JSON.parse(response.body)
        result.wont_be_nil
        result['id'].wont_be_nil
        result['id'].must_equal user_project_role.id
        result['user_id'].must_equal user_project_role.user_id
        result['project_id'].must_equal user_project_role.project_id
        result['role_id'].must_equal user_project_role.role_id
      end

      it 'fails to update project role' do
        put :update, project_id: project.id, id: current_project_admin_role.id, project_role: { role_id: 3 }, format: 'json'

        assert_response :bad_request

        user_project_role = UserProjectRole.find(current_project_admin_role.id)
        user_project_role.wont_be_nil
        user_project_role.role_id.must_equal ProjectRole::ADMIN.id

        result = JSON.parse(response.body)
        result['errors'].wont_be_nil
      end
    end
  end
end
