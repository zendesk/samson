require 'test_helper'

describe TddiumController do
  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }

  let(:payload) do
    {
      "event" => "test",
      "session" => 351279,
      "commit_id" => commit,
      "status" => "passed",
      "counts" => {
        "notstarted" => 0,
        "started" => 0,
        "passed" => 234.0,
        "failed" => 0.0,
        "pending" => 3.0,
        "skipped" => 0.0,
        "error" => 0.0
      },
      "workers" => 24,
      "branch" => "production",
      "ref" => "refs/head/production",
      "repository" => {
        "name" => "repo_name",
        "url" => "ssh =>//git@github.com/organization_name/repo_name",
        "org_name" => "organization_name"
      },
      "xid" => "372da4f69"
    }.with_indifferent_access
  end

  before do
    project.webhooks.create!(stage: stages(:test_staging), branch: "production")
  end

  it "triggers a deploy if there's a webhook mapping for the branch" do
    post :create, payload

    deploy = project.deploys.last
    deploy.commit.must_equal commit
  end

  it "doesn't trigger a deploy if there's no webhook mapping for the branch" do
    post :create, payload.merge(branch: "foobar")

    project.deploys.must_equal []
  end

  it "doesn't trigger a deploy if the build did not pass" do
    post :create, payload.merge(status: "failed")

    project.deploys.must_equal []
  end

  it "deploys as the Tddium user" do
    user = User.create!(name: "Tddium")

    post :create, payload

    project.deploys.last.user.must_equal user
  end

  it "creates the Tddium user if it does not exist" do
    post :create, payload

    User.find_by_name("Tddium").wont_be_nil
  end

  it "responds with 200 OK if the request is valid" do
    post :create, payload

    response.status.must_equal 200
  end

  it "responds with 404 Not Found if the repository url is invalid" do
    post :create, payload.merge(repository: { url: "foobar"} )

    response.status.must_equal 404
  end
end
