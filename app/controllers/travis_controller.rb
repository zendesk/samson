require 'digest/sha2'

class TravisController < ApplicationController
  rescue_from(ActiveRecord::RecordNotFound) { head :not_found }
  rescue_from(ActiveRecord::RecordNotSaved) { head :bad_request }

  skip_before_filter :login_users
  skip_before_filter :verify_authenticity_token

  def create
    unless project && deploy?
      return head :bad_request
    end

    stages = project.webhook_stages_for_branch(payload['branch'])
    deploy_service = DeployService.new(project, travis_user)

    stages.each do |stage|
      deploy_service.deploy!(stage, payload['commit'])
    end

    head :ok
  end

  protected

  def project
    @project ||= Project.find_by_token!(params[:token])
  end

  def payload
    @payload ||= JSON.parse(params['payload'])
  end

  def travis_authorization
    Digest::SHA2.hexdigest("#{repository}#{ENV['TRAVIS_TOKEN']}")
  end

  def deploy?
    payload['status_message'] == 'Passed'
  end

  def repository
    project.repository_url.match(/:([^:]+)\.git$/) do |match|
      return match[1]
    end
  end

  def travis_user
    name = "Travis"
    email = "deploy+travis@zendesk.com"

    User.create_with(name: name).find_or_create_by(email: email)
  end
end
