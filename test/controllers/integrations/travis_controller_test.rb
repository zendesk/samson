require_relative '../../test_helper'

describe Integrations::TravisController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:deploy_service) { stub(deploy!: nil) }

  setup do
    @orig_token, ENV["TRAVIS_TOKEN"] = ENV["TRAVIS_TOKEN"], "TOKEN"
    project.webhooks.create!(stage: stages(:test_staging), branch: "master")

    DeployService.stubs(:new).returns(deploy_service)
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

    describe "with an invalid project" do
      setup { post :create, token: 'abc123' }

      it "renders 404" do
        response.status.must_equal(404)
      end
    end

=begin
    describe "with no authorization" do
      setup { post :create, token: project.token }

      it "renders 400" do
        response.status.must_equal(400)
      end
    end

    describe "with invalid authorization" do
      let(:authorization) { "BLAHBLAH" }
      setup { post :create, token: project.token }

      it "renders 400" do
        response.status.must_equal(400)
      end
    end
=end

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
        describe "with an existing user" do
          let(:user) { users(:deployer) }

          let(:payload) {{
            status_message: 'Passed',
            branch: 'master',
            message: 'A change',
            committer_email: user.email,
            commit: '123abc',
            type: 'push'
          }}

          it "creates a deploy" do
            response.status.must_equal(200)

            assert_received(deploy_service, :deploy!) do |expect|
              expect.with stage, '123abc'
            end
          end
        end
      end
      describe "with the master branch" do
        describe "with an existing user and [deploy skip] in the message" do
          let(:user) { users(:deployer) }

          let(:payload) {{
            status_message: 'Passed',
            branch: 'master',
            message: 'A change but this time [deploy skip] is included',
            committer_email: user.email,
            commit: '123abc',
            type: 'push'
          }}

          it "doesn't deploy" do
            response.status.must_equal(200)

            project.deploys.must_equal []
          end
        end
      end
    end
  end
end
