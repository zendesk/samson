# frozen_string_literal: true
require 'shellwords'
require 'samson_gcloud/image_tagger'
require 'samson_gcloud/image_builder'

module SamsonGcloud
  class Engine < Rails::Engine
  end

  class << self
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

Samson::Hooks.callback :after_deploy do |deploy, _|
  SamsonGcloud::ImageTagger.tag(deploy) if ENV['GCLOUD_IMAGE_TAGGER'] == 'true'
end

Samson::Hooks.callback :project_permitted_params do
  :build_with_gcb
end
