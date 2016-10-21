# frozen_string_literal: true
class JenkinsController < ApplicationController
  include CurrentProject
  skip_around_action :login_user
  skip_before_action :require_project, only: [:ping]

  def ping
    logger.error "-"*60
	@deploy = Deploy.find(params[:deploy_id])	
	puts params.inspect
    logger.error "-"*60
    render :template => 
  end

end
