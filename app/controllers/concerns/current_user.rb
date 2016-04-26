module CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :current_user
    around_action :login_user

    # we record with reliable reset
    skip_before_action :set_paper_trail_enabled_for_controller
    skip_before_action :set_paper_trail_whodunnit
    skip_before_action :set_paper_trail_controller_info
  end

  private

  def current_user
    @current_user ||= warden.user
  end

  # Called from SessionsController for OmniAuth
  def current_user=(user)
    warden.set_user(user, event: :authentication)
  end

  def logout!
    warden.logout
  end

  def login_user
    warden.authenticate || begin
      Rails.logger.warn('Halted as unauthorized! threw :warden')
      throw(:warden) # middleware resolves this into UnauthorizedController
    end
    PaperTrail.with_whodunnit(current_user.id) { yield }
  end

  def warden
    request.env['warden']
  end
end
