# frozen_string_literal: true
require 'shellwords'
require 'samson_gcloud/image_tagger'
require 'samson_gcloud/image_builder'

module SamsonGcloud
  SCAN_WAIT_PERIOD = 10.minutes
  SCAN_SLEEP_PERIOD = 5.seconds

  class SamsonPlugin < Rails::Engine
  end

  class << self
    def gcr?(image)
      image.match?(/(^|\/|\.)gcr.io\//) # gcr.io or https://gcr.io or region like asia.gcr.io
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

Samson::Hooks.view :build_button, "samson_gcloud"

Samson::Hooks.callback :after_deploy do |deploy, job_execution|
  SamsonGcloud::ImageTagger.tag(deploy, job_execution.output) if ENV['GCLOUD_IMAGE_TAGGER'] == 'true'
end

Samson::Hooks.callback :project_docker_build_method_options do
  help_text =
    'Build docker images locally using Google cloud builder, disables pushing to any other registry,' \
    ' disables pulling from other registries.'

  [
    {
      label: 'Build docker with GCB CLI',
      method: 'build_with_gcb',
      help_text: help_text
    }
  ]
end

Samson::Hooks.callback :resolve_docker_image_tag do |image|
  SamsonGcloud::TagResolver.resolve_docker_image_tag image if ENV["GCLOUD_PROJECT"]
end
