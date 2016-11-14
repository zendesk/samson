# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe 'SamsonAuditLog::UserProjectRolePresenter' do
  let(:role) { UserProjectRole.first }

  describe '.present' do
    it 'returns filtered object' do
      object = SamsonAuditLog::UserProjectRolePresenter.present(role)
      object.keys.must_equal [:id, :user, :project, :role, :created_at, :updated_at]
      object[:role].keys.must_equal [:id, :name]
      object[:user].must_equal SamsonAuditLog::UserPresenter.present(role.user)
      object[:project].must_equal SamsonAuditLog::ProjectPresenter.present(role.project)
    end
  end
end
