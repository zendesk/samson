# frozen_string_literal: true
module HasRole
  def role
    Role.where(id: role_id).first
  end

  Role.all.each do |role|
    define_method "#{role.name}?" do
      role_id >= role.id
    end
  end
end
