# frozen_string_literal: true
require 'gitlab'
require 'git_diff_parser'

module SamsonGitlab
  class SamsonPlugin < Rails::Engine
    Gitlab.configure do |config|
      config.endpoint = "#{Rails.application.config.samson.gitlab.web_url}/api/v4"
      config.private_token = ENV['GITLAB_TOKEN']
    end
  end
end

Samson::Hooks.callback :repo_commit_from_ref do |project, reference|
  next unless project.gitlab?
  Gitlab.branch(project.repository_path, reference).commit.id
end

Samson::Hooks.callback :repo_compare do |project, previous_commit, reference|
  next unless project.gitlab?
  Gitlab::ChangesetPresenter.new(
    Gitlab.compare(project.repository_path, previous_commit, reference)
  ).build
end
