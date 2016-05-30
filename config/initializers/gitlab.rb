require 'gitlab'

# TODO: Caching

token = ENV['GITLAB_TOKEN']

unless Rails.env.test? || ENV['PRECOMPILE']
  raise "No GitLab token available" if token.blank?
end

GITLAB = GitLab.client(sudo: nil, endpoint: "#{ENV['GITLAB_URL']}/api/v3", private_token: ENV['GITLAB_TOKEN'])
