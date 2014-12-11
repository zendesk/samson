class Integrations::GithubController < Integrations::BaseController
  cattr_accessor(:github_hook_secret) { ENV['GITHUB_SECRET'] }

  HMAC_DIGEST = OpenSSL::Digest.new('sha1')

  protected

  def deploy?
    valid_signature? && valid_payload?
  end

  def valid_signature?
    hmac = OpenSSL::HMAC.hexdigest(
      HMAC_DIGEST,
      github_hook_secret,
      request.body.tap(&:rewind).read
    )

    request.headers['X-Hub-Signature'] == "sha1=#{hmac}"
  end

  def valid_payload?
    request.headers['X-Github-Event'] == 'push'
  end

  def commit
    params[:after]
  end

  def branch
    # Github returns full ref e.g. refs/heads/...
    params[:ref]
  end

  def user
    name = "Github"
    email = "deploy+github@samson-deployment.com"

    User.create_with(name: name).find_or_create_by(email: email)
  end
end
