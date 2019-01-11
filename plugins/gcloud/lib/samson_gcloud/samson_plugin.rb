# frozen_string_literal: true
require 'shellwords'
require 'samson_gcloud/image_tagger'
require 'samson_gcloud/image_builder'
require 'samson_gcloud/image_scanner'

module SamsonGcloud
  SCAN_WAIT_PERIOD = 10.minutes
  SCAN_SLEEP_PERIOD = 5.seconds

  class Engine < Rails::Engine
  end

  class << self
    def scan!(build, job, output)
      return true unless ENV['GCLOUD_IMAGE_SCANNER'] && job.project.show_gcr_vulnerabilities

      status = build.gcr_vulnerabilities_status_id
      scan_optional = !job.deploy.stage.block_on_gcr_vulnerabilities

      unless SamsonGcloud::ImageScanner::FINISHED.include?(status)
        output.puts 'Waiting for GCR scan to finish ...'
        (SCAN_WAIT_PERIOD / SCAN_SLEEP_PERIOD).times do
          status = SamsonGcloud::ImageScanner.scan(build.docker_repo_digest)
          break if SamsonGcloud::ImageScanner::FINISHED.include?(status) || scan_optional
          sleep(SCAN_SLEEP_PERIOD)
        end
        build.update_attributes!(gcr_vulnerabilities_status_id: status)
      end

      success = (status == SamsonGcloud::ImageScanner::SUCCESS)
      message = SamsonGcloud::ImageScanner.status(status)
      message += ", see #{SamsonGcloud::ImageScanner.result_url(build.docker_repo_digest)}" unless success
      output.puts message

      success || scan_optional
    end

    def cli_options(project: nil)
      Shellwords.split(ENV.fetch('GCLOUD_OPTIONS', '')) +
        ["--account", account, "--project", project || self.project]
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

Samson::Hooks.callback :after_deploy do |deploy, job_execution|
  SamsonGcloud::ImageTagger.tag(deploy, job_execution.output) if ENV['GCLOUD_IMAGE_TAGGER'] == 'true'
end

Samson::Hooks.callback :project_permitted_params do
  [:show_gcr_vulnerabilities]
end

Samson::Hooks.callback :project_docker_build_method_options do
  help_text = 'Build docker images locally using Google cloud builder, disables pushing to any other registry,' \
    ' disables pulling from other registries.'

  [
    {
      label: 'Build docker with GCB CLI',
      method: 'build_with_gcb',
      help_text: help_text
    }
  ]
end

Samson::Hooks.callback :stage_permitted_params do
  :block_on_gcr_vulnerabilities
end

Samson::Hooks.callback :ensure_build_is_successful do |*args|
  SamsonGcloud.scan!(*args)
end
