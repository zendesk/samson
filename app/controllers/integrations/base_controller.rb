# frozen_string_literal: true
class Integrations::BaseController < ApplicationController
  skip_around_action :login_user
  skip_before_action :verify_authenticity_token
  before_action :validate_token
  before_action :validate_request
  after_action :record_webhook

  def create
    unless deploy?
      record_log :info, "Request is not supposed to trigger a deploy"
      return render plain: @recorded_log.to_s
    end

    if branch
      create_release = project.create_release?(branch, service_type, service_name)
      record_log :info, "Branch #{branch} is release branch: #{create_release}"
      release = find_or_create_release if create_release
    else
      record_log :info, "No branch found, assuming this is a tag and not creating a release"
    end

    if project.build_docker_image_for_branch?(branch)
      create_docker_image(release)
    end

    stages = project.webhook_stages_for(branch, service_type, service_name)
    failed = deploy_to_stages(release, stages)

    if failed
      record_log :error, "Failed to start deploy to #{failed.name}"
    else
      record_log :info, "Deploying to #{stages.size} stages"
    end
    render plain: @recorded_log.to_s, status: (failed ? :unprocessable_entity : :ok)
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

  def find_or_create_release
    latest_release = project.releases.order(:id).last
    return latest_release if latest_release&.contains_commit?(commit)
    ReleaseService.new(project).release!(release_params)
  end

  # returns stage that failed to deploy or nil
  def deploy_to_stages(release, stages)
    deploy_service = DeployService.new(user)
    stages.detect do |stage|
      deploy = deploy_service.deploy!(stage, reference: release&.version || commit)
      if deploy.new_record?
        record_log :error, "Deploy to #{stage.name} failed: #{deploy.errors.full_messages}"
        true
      end
    end
  end

  def project
    @project ||= Project.find_by_token(params[:token])
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

  def validate_token
    project || render(plain: "Invalid token", status: :unauthorized)
  end

  def service_type
    'ci'
  end

  def service_name
    @service_name ||= self.class.name.demodulize.sub('Controller', '').downcase
  end

  def create_docker_image(release)
    build = find_or_create_build(branch)
    release.update_attribute(:build, build) if release
    DockerBuilderService.new(build).run!(push: true, tag_as_latest: true)
  end

  # TODO: use first_or_create here ... some weird rails bug breaks
  # test/controllers/integrations/base_controller_test.rb
  def find_or_create_build(label)
    options = {git_sha: commit}
    scope = project.builds
    scope.where(options).first || project.builds.create!(options.merge(
      git_ref: branch,
      description: message,
      creator: user,
      label: label
    ))
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
