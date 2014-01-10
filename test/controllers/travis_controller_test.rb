require 'test_helper'

describe TravisController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:deploy_service) { stub(deploy!: nil) }

  setup do
    @orig_token, ENV["TRAVIS_TOKEN"] = ENV["TRAVIS_TOKEN"], "TOKEN"

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
      setup { post :create, project: "hello" }

      it "renders 404" do
        response.status.must_equal(404)
      end
    end

    describe "with no authorization" do
      setup { post :create, project: project.name }

      it "renders 400" do
        response.status.must_equal(400)
      end
    end

    describe "with invalid authorization" do
      let(:authorization) { "BLAHBLAH" }
      setup { post :create, project: project.name }

      it "renders 400" do
        response.status.must_equal(400)
      end
    end

    describe "proper authorization" do
      let(:authorization) do
        Digest::SHA2.hexdigest("zendesk/#{project.repo_name}#{ENV["TRAVIS_TOKEN"]}")
      end

      setup do
        post :create, project: project.name,
          payload: JSON.dump(payload)
      end

      describe "failure" do
        let(:payload) {{
          status_message: 'Failure',
          branch: 'sdavidovitz/blah'
        }}

        it "renders 400" do
          response.status.must_equal(400)
        end
      end

      describe "with a non-deployment branch" do
        let(:payload) {{
          status_message: 'Passed',
          branch: 'sdavidovitz/blah'
        }}

        it "renders 400" do
          response.status.must_equal(400)
        end
      end

      describe "with a non-deployment branch and an #autodeploy message" do
        let(:user) { users(:deployer) }

        let(:payload) {{
          status_message: 'Passed',
          branch: 'sdavidovitz/hello',
          message: 'Hello #autodeploy',
          commit: '123abc',
          committer_email: user.email
        }}

        it "creates a deploy" do
          response.status.must_equal(200)

          assert_received(deploy_service, :deploy!) do |expect|
            expect.with stage, '123abc'
          end
        end
      end

      describe "with the master branch" do
        describe "with an existing user" do
          let(:user) { users(:deployer) }

          let(:payload) {{
            status_message: 'Passed',
            branch: 'master',
            committer_email: user.email,
            commit: '123abc'
          }}

          it "creates a deploy" do
            response.status.must_equal(200)

            assert_received(deploy_service, :deploy!) do |expect|
              expect.with stage, '123abc'
            end
          end
        end

        describe "with a new user" do
          let(:payload) {{
            status_message: 'Passed',
            branch: 'master',
            committer_email: 'test.user@example.com',
            committer_name: 'Test User',
            commit: '123abc'
          }}

          it "creates a deploy" do
            response.status.must_equal(200)

            assert_received(deploy_service, :deploy!) do |expect|
              expect.with stage, '123abc'
            end
          end
        end
      end
    end
  end
end
