# frozen_string_literal: true
module CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :can?
    before_action :login_user
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
  end

  def warden
    request.env['warden']
  end

  def unauthorized!
    called_from = caller(1..1).first
    Rails.logger.warn "Halted as unauthorized! threw :warden (called from #{called_from.sub(Rails.root.to_s, '')})"
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

  # tested via access checks in the actual controllers
  def authorize_resource!
    unauthorized! unless can?(resource_action, controller_name.to_sym)
  end

  def resource_action
    (['index', 'show'].include?(action_name) ? :read : :write)
  end

  def can?(action, resource_namespace, scope = nil)
    scope ||= current_project if respond_to?(:current_project, true)
    AccessControl.can?(current_user, action, resource_namespace, scope)
  end
end
