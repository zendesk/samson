# frozen_string_literal: true
class AccessRequestsController < ApplicationController
  before_action :ensure_enabled

  def self.feature_enabled?
    ENV['REQUEST_ACCESS_FEATURE'].present?
  end

  def new
    @projects = Project.all.order(:name)
    @roles = Role.all
  end

  def create
    options = {
      host: request.base_url,
      user: current_user,
    }
    [:manager_email, :reason, :project_ids, :role_id].each { |p| options[p] = params.require(p) }

    AccessRequestMailer.access_request_email(options).deliver_now
    current_user.update!(access_request_pending: true)

    flash[:notice] = 'Access request email sent.'
    redirect_back_or root_path
  end

  private

  def ensure_enabled
    raise ActionController::RoutingError, 'Not Found' unless self.class.feature_enabled?
  end
end
