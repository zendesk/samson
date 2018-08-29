# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe GithubStatusUpdatesController do
  let(:project) { projects(:test) }
  let(:sha) { "dc395381e650f3bac18457909880829fc20e34ba" }

  let(:payload) do
    {
      token: project.token,
      sha: sha,
      repository: {
        full_name: "hello/world"
      }
    }
  end

  with_env GITHUB_HOOK_SECRET: 'test'

  before do
    request.headers["X-Hub-Signature"] = signature_for(payload)
    request.headers["X-GitHub-Event"] = "status"
  end

  it "touches all releases related to the status event" do
    release = project.releases.create!(
      commit: sha,
      author: users(:deployer)
    )

    # Fast forward the clock.
    later = 1.minute.from_now
    Time.stubs(:now).returns later

    post :create, params: payload

    assert_response :success

    release.reload.updated_at.must_equal later
  end

  it "responds with status 401 if the signature is invalid" do
    request.headers["X-Hub-Signature"] = "yolo"

    post :create, params: payload

    assert_response :success
  end

  def signature_for(payload)
    hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['GITHUB_HOOK_SECRET'].to_s, payload.to_param)
    "sha1=#{hmac}"
  end
end
