module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :unauthorized!

    rescue_from CanCan::AccessDenied do
      unauthorized!
    end
  end

  def unauthorized!
    # Eventually to UnauthorizedController
    throw(:warden)
  end
end
