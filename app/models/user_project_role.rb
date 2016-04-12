class UserProjectRole < ActiveRecord::Base
  belongs_to :project
  belongs_to :user

  validates_presence_of :project, :user
  validates :role_id, inclusion: { in: ProjectRole.all.map(&:id) }
  validates_uniqueness_of :project_id, scope: :user_id

  def role
    ProjectRole.find(role_id)
  end

  ProjectRole.all.each do |role|
    define_method "is_#{role.name}?" do
      role_id >= role.id
    end
  end
end
