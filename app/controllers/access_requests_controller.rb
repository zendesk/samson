# frozen_string_literal: true
class AccessRequestsController < ApplicationController
  before_action :ensure_enabled

  def self.feature_enabled?
    ENV['REQUEST_ACCESS_FEATURE'].present?
  end

  def new
    @access_request = AccessRequest.new
  end

  def create
    @access_request = AccessRequest.new(access_request_params)

    if @access_request.valid?
      options = {
        host: request.base_url,
        user: current_user,
      }.merge(access_request_params).with_indifferent_access

      AccessRequestMailer.access_request_email(options).deliver_now
      current_user.update!(access_request_pending: true)

      flash[:notice] = 'Access request email sent.'
      redirect_back fallback_location: root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def access_request_params
    params.require(:access_request).permit(:manager_email, :reason, :role_id, project_ids: [])
  end

  def ensure_enabled
    raise ActionController::RoutingError, 'Not Found' unless self.class.feature_enabled?
  end
end
