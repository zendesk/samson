# frozen_string_literal: true

# This controller receives Status Event webhook updates from Github and makes
# sure all relevant Releases are touched such that caches based on the release
# `updated_at` timestamps are invalidated.
class GithubStatusUpdatesController < ApplicationController
  HMAC_DIGEST = OpenSSL::Digest.new('sha1')
  SECRET_TOKEN = ENV['GITHUB_HOOK_SECRET']

  skip_before_action :login_user
  skip_before_action :verify_authenticity_token

  def create
    project = Project.find_by_token(params[:token])
    event_type = request.headers.fetch("X-GitHub-Event")

    unless valid_signature?
      render plain: "invalid signature", status: 401
      return
    end

    if project && event_type == "status"
      # Touch all releases of the sha in the project.
      project.releases.where(commit: params[:sha].to_s).each(&:touch)
    end

    render plain: "OK COMPUTER", status: 200
  end

  private

  # https://developer.github.com/webhooks/securing/
  def valid_signature?
    return true if SECRET_TOKEN.nil?

    signature = request.headers.fetch('X-Hub-Signature').to_s
    request_body = request.body.tap(&:rewind).read
    hmac = OpenSSL::HMAC.hexdigest(HMAC_DIGEST, SECRET_TOKEN, request_body)

    Rack::Utils.secure_compare(signature, "sha1=#{hmac}")
  end
end
