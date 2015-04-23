require_relative '../../test_helper'

describe Integrations::TravisController do
  let(:sha) { "123abc" }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:release_service) { stub("release_service") }

  setup do
    Deploy.delete_all
    @orig_token, ENV["TRAVIS_TOKEN"] = ENV["TRAVIS_TOKEN"], "TOKEN"
    project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'travis')
    Project.any_instance.stubs(releases: stub("releases", create!: nil))
  end

  teardown do
    ENV["TRAVIS_TOKEN"] = @orig_token
  end

  describe "a POST to :create" do
    let(:authorization) { nil }

    setup do
      if authorization
        @request.headers["Authorization"] = authorization
      end
    end

    it "fails with unknown project" do
      assert_raises ActiveRecord::RecordNotFound do
        post :create, token: 'abc123'
      end
    end

    describe "with no authorization" do
      setup { post :create, token: project.token }

      it "renders ok" do
        response.status.must_equal(200)
      end
    end

    describe "with invalid authorization" do
      let(:authorization) { "BLAHBLAH" }
      setup { post :create, token: project.token }

      it "renders ok" do
        response.status.must_equal(200)
      end
    end

    describe "proper authorization" do
      let(:authorization) do
        Digest::SHA2.hexdigest("bar/foo#{ENV["TRAVIS_TOKEN"]}")
      end

      setup do
        post :create, token: project.token,
          payload: JSON.dump(payload)
      end

      describe "failure" do
        let(:payload) {{
          status_message: 'Failure',
          branch: 'sdavidovitz/blah',
          message: 'A change'
        }}

        it "renders ok" do
          response.status.must_equal(200)
        end
      end

      describe "with the master branch" do
        let(:user) { users(:deployer) }
        let(:status_message) { 'Passed' }
        let(:commit_message) { 'A change' }

        let(:payload) {{
          status_message: status_message,
          branch: 'master',
          message: commit_message,
          committer_email: user.email,
          commit: sha,
          type: 'push'
        }}

        describe "with status_message 'Passed'" do
          it "creates a deploy" do
            deploy = project.deploys.first
            deploy.try(:commit).must_equal(sha)
          end
        end

        describe "with status_message 'Fixed'" do
          let(:status_message) { 'Fixed' }

          it "creates a deploy" do
            deploy = project.deploys.first
            deploy.try(:commit).must_equal(sha)
          end
        end

        describe "with [deploy skip] in the message" do
          let(:commit_message) { 'A change but this time [deploy skip] is included' }

          it "doesn't deploy" do
            project.deploys.must_equal([])
          end
        end
        describe "with [skip deploy] in the message" do
          let(:commit_message) { 'A change but this time [skip deploy] is included' }

          it "doesn't deploy" do
            project.deploys.must_equal([])
          end
        end
      end
    end
  end
end
