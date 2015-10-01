class UserProjectRole < ActiveRecord::Base
  include HasProjectRole
  belongs_to :project
  belongs_to :user

  validates_presence_of :project, :user
  validates :role_id, inclusion: { in: ProjectRole.all.map(&:id) }
  validates_uniqueness_of :project_id, scope: :user_id
end
