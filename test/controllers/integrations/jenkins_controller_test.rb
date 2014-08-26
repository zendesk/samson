require_relative '../../test_helper'

describe Integrations::JenkinsController do
  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }

  let(:payload) do
    {
      build: {
        status: "SUCCESS",
        scm: {
          commit: 'dc395381e650f3bac18457909880829fc20e34ba',
          branch: 'origin/dev'
        }
      }
    }.with_indifferent_access
  end

  describe "normal" do
    before do
      project.webhooks.create!(stage: stages(:test_staging), branch: "origin/dev")
    end

    it "triggers a deploy if there's a webhook mapping for the branch" do
      post :create, payload.merge(token: project.token)

      deploy = project.deploys.last
      deploy.commit.must_equal commit
    end

    it "doesn't trigger a deploy if there's no webhook mapping for the branch" do
      post :create, payload.merge(token: project.token, build: { scm: { branch: "foobar" }})

      project.deploys.must_equal []
    end

    it "doesn't trigger a deploy if the build did not pass" do
      post :create, payload.merge(token: project.token, build: { status: "FAILURE" })

      project.deploys.must_equal []
    end

    it "deploys as the Jenkins user" do
      post :create, payload.merge(token: project.token)

      user = project.deploys.last.user
      user.name.must_equal "Jenkins"
    end

    it "creates the Jenkins user if it does not exist" do
      post :create, payload.merge(token: project.token)

      User.find_by_name("Jenkins").wont_be_nil
    end

    it "responds with 200 OK if the request is valid" do
      post :create, payload.merge(token: project.token)

      response.status.must_equal 200
    end

    it "responds with 404 Not Found if the token is invalid" do
      post :create, payload.merge(token: "foobar")

      response.status.must_equal 404
    end
  end
end
