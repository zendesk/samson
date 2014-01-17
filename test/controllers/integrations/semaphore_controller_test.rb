require_relative '../../test_helper'

describe Integrations::SemaphoreController do
  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }

  let(:payload) do
    {
      "branch_name" => "master",
      "branch_url" => "https://semaphoreapp.com/projects/44/branches/50",
      "project_name" => "base-app",
      "build_url" => "https://semaphoreapp.com/projects/44/branches/50/builds/15",
      "build_number" => 15,
      "result" => "passed",
      "started_at" => "2012-07-09T15:23:53Z",
      "finished_at" => "2012-07-09T15:30:16Z",
      "commit" => {
        "id" => commit,
        "url" => "https://github.com/renderedtext/base-app/commit/dc395381e650f3bac18457909880829fc20e34ba",
        "author_name" => "Vladimir Saric",
        "author_email" => "vladimir@renderedtext.com",
        "message" => "Update 'shoulda' gem.",
        "timestamp" => "2012-07-04T18:14:08Z"
      }
    }.with_indifferent_access
  end

  before do
    project.webhooks.create!(stage: stages(:test_staging), branch: "master")
  end

  it "triggers a deploy if there's a webhook mapping for the branch" do
    post :create, payload.merge(token: project.token)

    deploy = project.deploys.last
    deploy.commit.must_equal commit
  end

  it "doesn't trigger a deploy if there's no webhook mapping for the branch" do
    post :create, payload.merge(token: project.token, branch_name: "foobar")

    project.deploys.must_equal []
  end

  it "doesn't trigger a deploy if the build did not pass" do
    post :create, payload.merge(token: project.token, result: "failed")

    project.deploys.must_equal []
  end

  it "deploys as the Semaphore user" do
    post :create, payload.merge(token: project.token)

    user = project.deploys.last.user
    user.name.must_equal "Semaphore"
  end

  it "creates the Semaphore user if it does not exist" do
    post :create, payload.merge(token: project.token)

    User.find_by_name("Semaphore").wont_be_nil
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
