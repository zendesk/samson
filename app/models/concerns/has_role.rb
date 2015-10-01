module HasRole
  extend ActiveSupport::Concern

  def role
    Role.find(role_id)
  end

  Role.all.each do |role|
    define_method "is_#{role.name}?" do
      role_id >= role.id
    end

    define_method "is_not_#{role.name}?" do
      role_id < role.id
    end
  end
end
