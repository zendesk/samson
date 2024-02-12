# frozen_string_literal: true
class Integrations::BaseController < ApplicationController
  skip_before_action :login_user
  skip_before_action :verify_authenticity_token
  before_action :hide_token
  before_action :validate_token
  before_action :validate_request
  after_action :record_webhook
  wrap_parameters format: [] # wrapped params make debugging messy, avoid

  def create
    if !deploy? || skip?
      record_log :info, "Request is not supposed to trigger a deploy"
      return render json: {deploy_ids: [], messages: @recorded_log.to_s}
    end

    if branch
      create_release = project.create_release?(branch, service_type, service_name)
      record_log(
        :info,
        "Create release for branch [#{branch}], service_type [#{service_type}], service_name [#{service_name}]: " \
        "#{create_release}"
      )
      release = find_or_create_release if create_release
    else
      record_log :info, "No branch found, assuming this is a tag and not creating a release"
    end

    if project.build_docker_image_for_branch?(branch)
      create_docker_images
    end

    stages = project.webhook_stages_for(branch, service_type, service_name)
    deploy_service = DeployService.new(user)
    deploys = stages.map do |stage|
      options =
        if params[:deploy_branch_with_commit]
          {reference: branch, commit: commit} # nice display and exact commit
        else
          {reference: release&.version || commit} # exact display and commit
        end
      deploy_service.deploy(stage, options)
    end
    deploys.each do |deploy|
      if deploy.persisted?
        record_log :info, "Deploying #{deploy.id} to #{deploy.stage.name}"
      else
        record_log :error, "Failed deploying to #{deploy.stage.name}: #{deploy.errors.full_messages.to_sentence}"
      end
    end

    json = {
      deploy_ids: deploys.map(&:id).compact,
      messages: @recorded_log.to_s
    }
    json[:release] = release if release

    if params[:includes].to_s.split(',').include?('status_urls')
      json[:status_urls] = deploys.map(&:status_url).compact
    end

    render(
      json: json,
      status: (deploys.all?(&:persisted?) ? :ok : :unprocessable_entity)
    )
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
    {commit: commit, author: user}
  end

  def find_or_create_release
    latest_release = project.releases.order(:id).last
    return latest_release if latest_release&.contains_commit?(commit)
    ReleaseService.new(project).release(release_params)
  end

  def project
    @project ||= Project.find_by_token(params[:token])
  end

  def contains_skip_token?(message)
    ["[deploy skip]", "[skip deploy]"].any? do |token|
      message&.include?(token)
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

  def skip?
    contains_skip_token?(message)
  end

  def validate_token
    project || render(json: {deploy_ids: [], messages: 'Invalid token'}, status: :unauthorized)
  end

  def hide_token
    request.env["PATH_INFO"] =
      request.env["PATH_INFO"].sub(params[:token], "hidden-#{project&.permalink || "project-not-found"}-token")
  end

  def service_type
    'ci'
  end

  def service_name
    # keep in sync with lib/samson/integration.rb regex
    @service_name ||= self.class.name.demodulize.sub('Controller', '').underscore
  end

  def create_docker_images
    scope = project.builds
    project.dockerfile_list.each do |dockerfile|
      options = {git_sha: commit, dockerfile: dockerfile}
      next if scope.where(options).first

      build = project.builds.create!(
        options.merge(
          git_ref: branch,
          description: message,
          creator: user,
          name: "Release #{branch}"
        )
      )
      DockerBuilderService.new(build).run(tag_as_latest: true)
    end
  end

  def record_log(level, message)
    (@recorded_log ||= +"") << "#{level.upcase}: #{message}\n"
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
