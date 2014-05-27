require 'digest/sha2'

class Integrations::TravisController < Integrations::BaseController
  protected

  def payload
    @payload ||= JSON.parse(params.fetch('payload', '{}'))
  end

  def travis_authorization
    Digest::SHA2.hexdigest("#{project.github_repo}#{ENV['TRAVIS_TOKEN']}")
  end

  def deploy?
    project &&
      %w{Passed Fixed}.include?(payload['status_message']) &&
      payload['type'] == 'push' &&
      !skip?
  end

  def skip?
    ["[deploy skip]", "[skip deploy]"].any? do |token|
      payload['message'].include?(token)
    end
  end

  def branch
    payload['branch']
  end

  def commit
    payload['commit']
  end

  def user
    name = "Travis"
    email = "deploy+travis@zendesk.com"

    User.create_with(name: name).find_or_create_by(email: email)
  end
end
