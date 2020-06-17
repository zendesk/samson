# frozen_string_literal: true
class UserProjectRole < ActiveRecord::Base
  include HasRole
  extend AuditOnAssociation

  audited
  audits_on_association :user, :user_project_roles do |user|
    user.user_project_roles.map { |upr| [upr.project.permalink, upr.role_id] }.to_h
  end

  belongs_to :project, inverse_of: :user_project_roles
  belongs_to :user, inverse_of: :user_project_roles

  ROLES = [Role::DEPLOYER, Role::ADMIN].freeze

  validates :project, :user, presence: true
  validates :role_id, inclusion: {in: ROLES.map(&:id)}
  validates :project_id, uniqueness: {scope: :user_id}
end
Samson::Hooks.load_decorators(UserProjectRole)
