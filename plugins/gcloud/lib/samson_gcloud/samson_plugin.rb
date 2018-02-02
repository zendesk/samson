# frozen_string_literal: true
require 'shellwords'
require 'samson_gcloud/image_tagger'
require 'samson_gcloud/image_builder'
require 'samson_gcloud/image_scanner'

module SamsonGcloud
  class Engine < Rails::Engine
  end

  class << self
    def scan!(build, job, output)
      return true unless ENV['GCLOUD_IMAGE_SCANNER'] && job.project.show_gcr_vulnerabilities

      status = build.gcr_vulnerabilities_status_id
      unless SamsonGcloud::ImageScanner::FINISHED.include?(status)
        status = SamsonGcloud::ImageScanner.scan(build)
        build.update_attributes!(gcr_vulnerabilities_status_id: status)
      end

      success = (status == SamsonGcloud::ImageScanner::SUCCESS)
      message = SamsonGcloud::ImageScanner.status(status)
      message += ", see #{SamsonGcloud::ImageScanner.result_url(build)}" unless success
      output.puts message

      success || !job.deploy.stage.block_on_gcr_vulnerabilities
    end

    def cli_options
      Shellwords.split(ENV.fetch('GCLOUD_OPTIONS', '')) +
        ["--account", account, "--project", project]
    end

    def project
      ENV.fetch("GCLOUD_PROJECT").shellescape
    end

    def account
      ENV.fetch("GCLOUD_ACCOUNT").shellescape
    end
  end
end

Samson::Hooks.view :project_form_checkbox, "samson_gcloud/project_form_checkbox"
Samson::Hooks.view :build_button, "samson_gcloud/build_button"
Samson::Hooks.view :stage_form_checkbox, "samson_gcloud/stage_form_checkbox"
Samson::Hooks.view :build_show, "samson_gcloud/build_show"

Samson::Hooks.callback :after_deploy do |deploy, _|
  SamsonGcloud::ImageTagger.tag(deploy) if ENV['GCLOUD_IMAGE_TAGGER'] == 'true'
end

Samson::Hooks.callback(:docker_build_style) do
  "build locally with gcloud"
end

Samson::Hooks.callback :project_permitted_params do
  [:build_with_gcb, :show_gcr_vulnerabilities]
end

Samson::Hooks.callback :stage_permitted_params do
  :block_on_gcr_vulnerabilities
end

Samson::Hooks.callback :ensure_build_is_successful do |*args|
  SamsonGcloud.scan!(*args)
end
