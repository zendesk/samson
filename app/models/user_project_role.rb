# frozen_string_literal: true
class UserProjectRole < ActiveRecord::Base
  include HasRole

  audited

  belongs_to :project
  belongs_to :user

  ROLES = [Role::DEPLOYER, Role::ADMIN].freeze

  validates_presence_of :project, :user
  validates :role_id, inclusion: { in: ROLES.map(&:id) }
  validates_uniqueness_of :project_id, scope: :user_id

  around_save :record_change_in_user_audit
  around_destroy :record_change_in_user_audit

  private

  # tested via user_test.rb
  def record_change_in_user_audit
    old = user.user_project_roles.to_a
    yield
    user.record_project_role_change(old)
  end
end
