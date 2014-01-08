require 'digest/sha2'

class TravisController < ApplicationController
  rescue_from(ActiveRecord::RecordNotFound) { head :not_found }
  rescue_from(ActiveRecord::RecordInvalid) { head :bad_request }

  skip_before_filter :login_users
  skip_before_filter :verify_authenticity_token

  # POST /travis?project="Zendesk Carson"
  def create
    if travis_authorization == request.authorization && deploy?
      stage = project.stages.first
      deploy_service = DeployService.new(project, user)
      deploy = deploy_service.deploy!(stage, payload["commit"])

      head :ok
    else
      head :bad_request
    end
  end

  protected

  def project
    @project ||= Project.find_by_name!(params[:project])
  end

  def deploy?
    payload['status_message'] == 'Passed' &&
      (payload['branch'] == 'master' || payload['message'] =~ /#autodeploy/)
  end

  def payload
    @payload ||= JSON.parse(params['payload'])
  end

  def travis_authorization
    Digest::SHA2.hexdigest("zendesk/#{project.repo_name}#{ENV['TRAVIS_TOKEN']}")
  end

  def user
    @user ||= User.find_or_create_by!(email: payload['committer_email']) do |user|
      user.name = payload['committer_name']
    end
  end
end
