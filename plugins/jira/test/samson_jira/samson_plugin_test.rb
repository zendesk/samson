# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe SamsonJira do
  describe :project_permitted_params do
    it "adds jira_issue_prefix" do
      params = Samson::Hooks.fire(:project_permitted_params).flatten
      params.must_include :jira_issue_prefix
    end
  end

  describe :stage_permitted_params do
    it "adds jira_transition_id" do
      params = Samson::Hooks.fire(:stage_permitted_params).flatten
      params.must_include :jira_transition_id
    end
  end

  describe :after_deploy do
    def fire
      Samson::Hooks.fire(:after_deploy, deploy, stub("JobEx", output: output))
    end

    def stub_issues(issues)
      deploy.changeset.instance_variable_set(:@jira_issues, issues.map { |url| Changeset::JiraIssue.new(url) })
    end

    only_callbacks_for_plugin :after_deploy
    with_env JIRA_BASE_URL: "https://foo.bar.com/browse", JIRA_USER: "foo@bar.com", JIRA_TOKEN: "abcd"

    let(:deploy) { deploys(:succeeded_test) }
    let(:output) { StringIO.new }

    before do
      deploy.project.jira_issue_prefix = "FOO"
      deploy.stage.jira_transition_id = "abc123"
      stub_issues ["https://foo.bar.com/browse/FOO-123"]
    end

    it "transitions" do
      assert_request(:post, "https://foo.bar.com/rest/api/3/issue/FOO-123/transitions") { fire }
      output.string.must_equal "Transitioned JIRA issue https://foo.bar.com/browse/FOO-123\n"
    end

    it "shows error when transitioning fails" do
      reply = {status: 400, body: {errorMessages: ["Oops"]}.to_json}
      assert_request(:post, "https://foo.bar.com/rest/api/3/issue/FOO-123/transitions", to_return: reply) { fire }
      output.string.must_equal "Failed to transition JIRA issue https://foo.bar.com/browse/FOO-123:\nOops\n"
    end

    it "does not transition on failure" do
      deploy.job.status = "errored"
      fire
      output.string.must_equal ""
    end

    it "does not transition without url" do
      with_env JIRA_BASE_URL: nil do
        fire
        output.string.must_equal ""
      end
    end

    it "does not transition without user" do
      with_env JIRA_USER: nil do
        fire
        output.string.must_equal ""
      end
    end

    it "does not transition without token" do
      with_env JIRA_TOKEN: nil do
        fire
        output.string.must_equal ""
      end
    end

    it "does not transition without prefix" do
      deploy.project.jira_issue_prefix = ""
      fire
      output.string.must_equal ""
    end

    it "does not transition without transition" do
      deploy.stage.jira_transition_id = ""
      fire
      output.string.must_equal ""
    end

    it "does not transition other projects" do
      stub_issues ["https://foo.bar.com/browse/BAR-123"]
      fire
      output.string.must_equal ""
    end
  end
end
