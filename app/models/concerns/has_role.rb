# frozen_string_literal: true
module HasRole
  def role
    Role.find(role_id)
  end

  Role.all.each do |role| # rubocop:disable Lint/RedundantCopDisableDirective Rails/FindEach
    define_method "#{role.name}?" do
      role_id >= role.id
    end
  end
end
