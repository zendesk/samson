# frozen_string_literal: true

class AuditPresenter::UserPresenter
  ## User presenter for Audit Logger

  def self.present(user)
    if user
      {
        id: user.id,
        email: user.email,
        name: user.name
      }
    end
  end
end
