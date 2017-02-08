# frozen_string_literal: true
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
    warden.authenticate || unauthorized!
    PaperTrail.with_whodunnit_user(current_user) { yield }
  end

  def warden
    request.env['warden']
  end

  def unauthorized!
    Rails.logger.warn "Halted as unauthorized! threw :warden (called from #{caller.first.sub(Rails.root.to_s, '')})"
    throw :warden # Warden::Manager middleware catches this and calls UnauthorizedController
  end

  def authorize_super_admin!
    unauthorized! unless current_user.super_admin?
  end

  def authorize_admin!
    unauthorized! unless current_user.admin?
  end

  def authorize_project_admin!
    unauthorized! unless current_user.admin_for?(current_project)
  end

  def authorize_deployer!
    unauthorized! unless current_user.deployer?
  end

  def authorize_project_deployer!
    unauthorized! unless current_user.deployer_for?(current_project)
  end

  def authorize_resource!
    case controller_name
    when 'builds'
      authorize_project_deployer!
    when 'locks'
      if @project
        authorize_project_deployer!
      else
        authorize_admin!
      end
    else
      raise "Unsupported controller"
    end
  end
end
