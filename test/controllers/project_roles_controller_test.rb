# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ProjectRolesController do
  let(:project) { projects(:test) }

  as_a_viewer do
    unauthorized :post, :create, project_id: :foo
  end

  as_a_deployer do
    unauthorized :post, :create, project_id: :foo
  end

  as_a_project_admin do
    describe "#create" do
      def create(role_id)
        post :create, project_id: project, user_id: new_admin.id, role_id: role_id
      end

      let(:new_admin) { users(:deployer) }

      it 'creates new project role' do
        create Role::ADMIN.id
        assert_response :success
        role = new_admin.user_project_roles.first
        role.role_id.must_equal Role::ADMIN.id
      end

      it 'updates existing role' do
        new_admin.user_project_roles.create!(role_id: Role::DEPLOYER.id, project: project)
        create Role::ADMIN.id
        assert_response :success
        role = new_admin.user_project_roles.first.reload
        role.role_id.must_equal Role::ADMIN.id
      end

      it 'deletes existing role when setting to None' do
        new_admin.user_project_roles.create!(role_id: Role::DEPLOYER.id, project: project)
        create ''
        assert_response :success
        refute new_admin.reload.user_project_roles.first
      end

      it 'does nothing when setting from None to None' do
        create ''
        assert_response :success
        refute new_admin.user_project_roles.first
      end

      it 'clears the access request pending flag' do
        check_pending_request_flag(new_admin) do
          create Role::ADMIN.id
          assert_response :success
        end
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
