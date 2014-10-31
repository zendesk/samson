require_relative '../../test_helper'

describe Integrations::GithubController do
  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }

  let(:payload) do
    {
      ref: 'refs/heads/origin/dev',
      head: commit
    }.with_indifferent_access
  end

  before do
    Deploy.delete_all

    project.webhooks.create!(stage: stages(:test_staging), branch: "origin/dev")
  end

  it 'does not deploy if signature is invalid' do
    request.headers['X-Github-Event'] = 'push'
    request.headers['X-Hub-Signature'] = "nope"

    post :create, payload.merge(token: project.token)

    project.deploys.must_equal []
    response.status.must_equal 200
  end

  it 'does not deploy if event is invalid' do
    request.headers['X-Github-Event'] = 'event'

    hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['GITHUB_SECRET'], payload.to_param)
    request.headers['X-Hub-Signature'] = "sha1=#{hmac}"

    post :create, payload.merge(token: project.token)

    project.deploys.must_equal []
    response.status.must_equal 200
  end

  describe 'with a valid signature' do
    let(:user_name) { 'Github' }

    before do
      request.headers['X-Github-Event'] = 'push'

      hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['GITHUB_SECRET'], payload.to_param)
      request.headers['X-Hub-Signature'] = "sha1=#{hmac}"
    end

    it "triggers a deploy if there's a webhook mapping for the branch" do
      post :create, payload.merge(token: project.token)

      deploy = project.deploys.first
      deploy.commit.must_equal commit
    end

    describe 'if there is no webhook mapping' do
      let(:payload) do
        {
          ref: 'refs/heads/origin/foobar',
          head: commit
        }.with_indifferent_access
      end

      it "doesn't trigger a deploy" do
        post :create, payload.merge(token: project.token)

        project.deploys.must_equal []
      end
    end

    it "deploys as the correct user" do
      post :create, payload.merge(token: project.token)

      user = project.deploys.first.user
      user.name.must_equal user_name
    end

    it "creates the ci user if it does not exist" do
      post :create, payload.merge(token: project.token)

      User.find_by_name(user_name).wont_be_nil
    end

    it "responds with 200 OK if the request is valid" do
      post :create, payload.merge(token: project.token)

      response.status.must_equal 200
    end

    it "responds with 422 OK if deploy cannot be started" do
      post :create, payload.merge(token: project.token)
      post :create, payload.merge(token: project.token)

      response.status.must_equal 422
    end

    it "responds with 404 Not Found if the token is invalid" do
      post :create, payload.merge(token: "foobar")

      response.status.must_equal 404
    end
  end
end
