# frozen_string_literal: true
class Integrations::BaseController < ApplicationController
  skip_around_action :login_user
  skip_before_action :verify_authenticity_token
  before_action :validate_request
  after_action :record_webhook

  def create
    unless deploy?
      record_log :info, "Request is not a deploy"
      return head(:ok)
    end

    release = project.create_releases_for_branch?(branch)
    record_log :info, "Branch #{branch} is release branch: #{release}"

    if release
      create_build_record

      if project.deploy_with_docker? && project.auto_release_docker_image?
        create_docker_image
      end
    end

    if deploy_to_stages
      record_log :info, "Starting deploy to all stages"
      head(:ok)
    else
      head(:unprocessable_entity, message: 'Failed to start all deploys')
    end
  end

  protected

  # These methods can/must be overridden by subclasses

  def validate_request
    true # can be overridden in subclasses
  end

  def commit
    raise NotImplementedError, "#commit must be overridden in a subclass"
  end

  def deploy?
    raise NotImplementedError, "#deploy? must be overridden in a subclass"
  end

  def release_params
    { commit: commit, author: user }
  end

  def create_new_release
    unless project.last_release_contains_commit?(commit)
      release_service = ReleaseService.new(project)
      release_service.create_release!(release_params)
    end
  end

  def deploy_to_stages
    stages = project.webhook_stages_for(branch, service_type, service_name)
    deploy_service = DeployService.new(user)

    stages.all? do |stage|
      deploy_service.deploy!(stage, reference: commit).persisted?
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
    @user ||= begin
      name = self.class.name.split("::").last.sub("Controller", "")
      email = "deploy+#{name.underscore}@#{Rails.application.config.samson.email.sender_domain}"

      User.create_with(name: name, integration: true).find_or_create_by(email: email)
    end
  end

  def message
    ''
  end

  private

  def service_type
    'ci'
  end

  def service_name
    @service_name ||= self.class.name.demodulize.sub('Controller', '').downcase
  end

  def create_build_record
    release = create_new_release || latest_release
    @build = project.builds.where(git_sha: commit).last || project.builds.create!(
      git_ref: branch,
      git_sha: commit,
      description: message,
      creator: user,
      label: release.version,
      releases: [release]
    )
  end

  def create_docker_image
    DockerBuilderService.new(@build).run!(push: true, tag_as_latest: true)
  end

  def latest_release
    project.releases.order(:id).last
  end

  def record_log(level, message)
    (@recorded_log ||= "".dup) << "#{level.upcase}: #{message}\n"
    Rails.logger.public_send(level, message)
  end

  def record_webhook
    WebhookRecorder.record(
      project,
      request: request,
      response: response,
      log: @recorded_log.to_s
    )
  end
end
