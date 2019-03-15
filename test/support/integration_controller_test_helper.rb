# frozen_string_literal: true
module IntegrationsControllerTestHelper
  def test_regular_commit(user_name, options, &block)
    describe "regular commit" do
      before(&block) if block

      it "triggers a deploy if there is a webhook mapping for the branch" do
        post :create, params: payload.deep_merge(token: project.token)
        assert_response :success
        deploy = project.deploys.first
        deploy.commit.must_equal commit
      end

      it "does not trigger a deploy if there is no webhook mapping for the branch" do
        post :create, params: payload.deep_merge(token: project.token).deep_merge(options.fetch(:no_mapping))
        assert_response :success
        project.deploys.must_equal []
      end

      if (failed = options.fetch(:failed))
        it "does not trigger a deploy if the build did not pass" do
          post :create, params: payload.deep_merge(token: project.token).deep_merge(failed)
          assert_response :success
          project.deploys.must_equal []
        end
      end

      it "deploys as the correct user" do
        post :create, params: payload.deep_merge(token: project.token)
        assert_response :success
        user = project.deploys.first.user
        user.name.must_equal user_name
      end

      it "creates the ci user if it does not exist" do
        post :create, params: payload.deep_merge(token: project.token)
        assert_response :success
        assert User.find_by_name(user_name)
      end

      it "responds with 200 OK if the request is valid" do
        post :create, params: payload.deep_merge(token: project.token)
        assert_response :success
      end

      it "responds with 422 OK if deploy cannot be started" do
        DeployService.stubs(new: stub(deploy: Deploy.new(stage: stages(:test_production))))
        post :create, params: payload.deep_merge(token: project.token)
        assert_response :unprocessable_entity
      end

      it "responds with 401 Unauthorized if the token is invalid" do
        post :create, params: payload.deep_merge(token: "foobar")
        assert_response :unauthorized
      end
    end
  end

  def it_deploys(name = "", &block)
    it "deploys #{name}".strip do
      instance_exec(&block) if block
      post :create, params: payload.merge(token: project.token)
      response.status.must_equal 200, response.body
      project.deploys.count.must_equal 1, response.body
    end
  end

  def it_does_not_deploy(name, status: 200, &block)
    it "does not deploy #{name}" do
      instance_exec(&block) if block
      post :create, params: payload.merge(token: project.token)
      response.status.must_equal status, response.body
      project.deploys.count.must_equal 0, response.body
    end
  end

  def it_ignores_skipped_commits
    describe "skipping" do
      # sanity check so we know this test has no false-positives where there is nothing deployed
      it "creates a deploy with a normal message" do
        post :create, params: payload.merge(token: project.token)
        assert_response :success
        project.deploys.size.must_equal 1
      end

      ['[skip deploy]', '[deploy skip]'].each do |message|
        describe "with [deploy skip]" do
          let(:commit_message) { "Hey there #{message}" }

          it "doesn't trigger a deploy" do
            post :create, params: payload.merge(token: project.token)
            assert_response :success
            project.deploys.must_equal []
          end
        end
      end
    end
  end
end
