require 'test_helper'

describe SemaphoreController do
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
    }
  end

  it "triggers a deploy if the master green passed" do
    post :create, payload.merge(token: project.id)

    deploy = project.deploys.last
    deploy.commit.must_equal commit
  end

  it "responds with 200 OK if the request is valid" do
    post :create, payload.merge(token: project.id)

    response.status.must_equal 200
  end

  it "responds with 404 Not Found if the token is invalid" do
    post :create, payload.merge(token: "foobar")

    response.status.must_equal 404
  end
end
