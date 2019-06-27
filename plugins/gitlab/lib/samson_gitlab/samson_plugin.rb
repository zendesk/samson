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

Samson::Hooks.callback :changeset_api_request do |changeset, method|
  next unless changeset.project.gitlab?
  begin
    case method
    when :branch
      Gitlab.branch(changeset.repo, changeset.commit).commit.id
    when :compare
      Gitlab::ChangesetPresenter.new(
        Gitlab.compare(changeset.repo, changeset.previous_commit, changeset.commit)
      ).build
    else
      raise NoMethodError
    end
  rescue Gitlab::Error::ResponseError => e
    raise "GitLab: #{e.message}"
  end
end
