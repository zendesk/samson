# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGitlab do
  it 'configures GitLab API client' do
    Gitlab.endpoint.must_equal "#{Rails.application.config.samson.gitlab.web_url}/api/v4"
    Gitlab.private_token.must_equal ENV['GITLAB_TOKEN']
  end
end
