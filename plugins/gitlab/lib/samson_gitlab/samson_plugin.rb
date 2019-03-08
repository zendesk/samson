# frozen_string_literal: true
require 'gitlab'
require 'git_diff_parser'

module SamsonGitlab
  class Engine < Rails::Engine
    Gitlab.configure do |config|
      config.endpoint = "#{Rails.application.config.samson.gitlab.web_url}/api/v4"
      config.private_token = ENV['GITLAB_TOKEN']
    end
  end
end
