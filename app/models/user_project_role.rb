class UserProjectRole < ActiveRecord::Base
  include HasRole

  belongs_to :project
  belongs_to :user

  ROLES = [Role::DEPLOYER, Role::ADMIN].freeze

  validates_presence_of :project, :user
  validates :role_id, inclusion: { in: ROLES.map(&:id) }
  validates_uniqueness_of :project_id, scope: :user_id
end
