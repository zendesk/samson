module HasProjectRole
  extend ActiveSupport::Concern

  def role
    ProjectRole.find(role_id)
  end

  ProjectRole.all.each do |role|
    define_method "is_project_#{role.name}?" do
      role_id >= role.id
    end
  end
end
