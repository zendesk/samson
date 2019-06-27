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

  validates_presence_of :project, :user
  validates :role_id, inclusion: {in: ROLES.map(&:id)}
  validates_uniqueness_of :project_id, scope: :user_id
end
