# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe AutomatedDeploysController do
  def assert_created
    assert_difference 'Stage.count', +1 do
      assert_difference 'Deploy.count', +1 do
        post_create
        assert_response :created
      end
    end
  end

  before do
    # trigger deploy validation error we saw in staging ... validate_stage_uses_deploy_groups_properly
    # we set $DEPLOY_GROUPS via before_command but do not select any deploy group
    DeployGroup.stubs(enabled?: true)
    commands(:echo).update_column(:command, 'cap $DEPLOY_GROUPS deploy')
  end

  oauth_setup!

  describe "#create" do
    def post_create
      post :create, params: {project_id: :foo, deploy_group: 'pod100', env: {'FOO' => "bar\nba$"}}, format: :json
    end

    let(:template) { stages(:test_staging) }
    let(:copied_deploy) { deploys(:failed_staging_test) }

    before do
      copied_deploy.update_column(:buddy_id, users(:admin).id) # buddy so we can test for it
      Job.update_all(status: 'succeeded') # multiple deploys so we know ordering works
    end

    it "creates a new stage and deploys" do
      assert_created

      # copies over the buddy id and uses current user as use
      Deploy.first.user.must_equal user
      Deploy.first.buddy_id.must_equal copied_deploy.buddy_id

      # env vars are correctly encoded
      Job.last.command.must_include "export PARAM_FOO=bar\\\\nba\\$\n"
    end

    it "sets command when configured" do
      command = Command.create!(command: "foo")
      with_env "AUTOMATED_DEPLOY_COMMAND_ID" => command.id.to_s do
        assert_created
        Stage.last.script.must_equal "foo\ncap $DEPLOY_GROUPS deploy"
      end
    end

    describe "with email" do
      with_env "AUTOMATED_DEPLOY_FAILURE_EMAIL" => "foo@bar.com"

      it "sets email when configured" do
        user.update_column(:integration, true)
        assert_created
        Stage.last.static_emails_on_automated_deploy_failure.must_equal "foo@bar.com"
      end

      it "raises when seting the email would have no effect" do
        e = assert_raises(Minitest::UnexpectedError) { assert_created }
        e.error.class.must_equal ArgumentError
      end
    end

    it "reuses an existing stage and deploys" do
      template.update_column(:name, Stage::AUTOMATED_NAME)

      refute_difference 'Stage.count' do
        assert_difference 'Deploy.count', +1 do
          post_create
          assert_response :created
        end
      end
    end

    it "uses last deploys user as buddy if it had no buddy" do
      copied_deploy.update_column(:buddy_id, nil)
      assert_created
      Deploy.first.buddy_id.must_equal copied_deploy.job.user_id
    end

    it "does not deploy other projects deploy" do
      Deploy.update_all(project_id: 12121)
      post_create
      assert_response :bad_request
    end

    it "fails when no template was found" do
      template.update_column(:is_template, false)
      post_create
      assert_response :bad_request
      response.body.must_equal "{\"error\":\"Unable to find template for Foo\"}"
    end

    it "fails when new stage could not be saved" do
      Stage.any_instance.expects(:valid?).returns(false)
      post_create
      assert_response :bad_request
      response.body.must_equal "{\"error\":\"Unable to save stage: []\"}"
    end

    it "fails when no deploy could be found" do
      Job.update_all(status: 'cancelled')
      post_create
      assert_response :bad_request
      response.body.must_equal "{\"error\":\"Unable to find succeeded deploy for Automated Deploys\"}"
    end

    it "fails when deploy could not be started" do
      Deploy.any_instance.expects(:valid?).returns(false) # validation fails
      post_create
      assert_response :bad_request
      response.body.must_equal "{\"error\":\"Unable to start deploy: []\"}"
    end
  end
end
