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
  if changeset.project.gitlab?
    begin
      case method
      when :branch
        sha = Gitlab.branch(changeset.repo, changeset.commit).commit.id
        changeset.instance_variable_set(:@commit, sha)
      when :compare
        Gitlab::ChangesetPresenter.new(
          Gitlab.compare(changeset.repo, changeset.previous_commit, changeset.commit)
        ).build
      else
        raise NoMethodError
      end
    rescue Gitlab::Error::ResponseError => e
      Changeset::NullComparison.new("GitLab: #{e.message}")
    end
  end
end
