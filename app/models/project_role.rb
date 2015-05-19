class ProjectRole < ActiveRecord::Base
  include HasRole
  belongs_to :project
  belongs_to :user

  validates_presence_of :project, :user
  validates :role_id, inclusion: { in: [1,2] }   # either "Deployer" or "Admin"
end
