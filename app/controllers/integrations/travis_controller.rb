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
      payload['status_message'] == 'Passed' &&
      payload['type'] == 'push' &&
      !skip?
  end

  def skip?
    payload['message'].include?("[deploy skip]")
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
