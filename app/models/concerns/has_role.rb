module HasRole
  def role
    Role.find(role_id)
  end

  Role.all.each do |role|
    define_method "#{role.name}?" do
      role_id >= role.id
    end
  end
end
