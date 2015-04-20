class Integrations::BaseController < ApplicationController
  skip_before_action :login_users
  skip_before_action :verify_authenticity_token

  def create
    if deploy?
      create_new_release
      unless deploy_to_stages
        head :unprocessable_entity
        return
      end
    end

    head :ok
  end

  protected

  def create_new_release
    if project.create_releases_for_branch?(branch)
      unless project.last_released_with_commit?(commit)
        release_service = ReleaseService.new(project)
        release_service.create_release!(commit: commit, author: user)
      end
    end
  end

  def deploy_to_stages
    stages = project.webhook_stages_for(branch, service_type, service_name)
    deploy_service = DeployService.new(user)

    stages.all? do |stage|
      deploy_service.deploy!(stage, commit).persisted?
    end
  end

  def project
    @project ||= Project.find_by_token!(params[:token])
  end

  def contains_skip_token?(message)
    ["[deploy skip]", "[skip deploy]"].any? do |token|
      message.include?(token)
    end
  end

  def user
    name = self.class.name.split("::").last.sub("Controller", "")
    email = "deploy+#{name.underscore}@#{Rails.application.config.samson.email.sender_domain}"

    User.create_with(name: name, integration: true).find_or_create_by(email: email)
  end

  private

  def service_type
    'ci'
  end

  def service_name
    @service_name ||= self.class.name.demodulize.sub('Controller', '').downcase
  end
end
