require_relative '../test_helper'

class DeployServiceTest < ActiveSupport::TestCase
  let(:project) { projects(:test) }
  let(:user) { users(:deployer) }
  let(:service) { DeployService.new(project, user) }
  let(:stage) { stages(:test_staging) }
  let(:reference) { "staging" }
  let(:job) { project.jobs.create!(user: user, command: "foo", status: "succeeded") }
  let(:deploy) { stub(user: user, job: job, changeset: "changeset") }
  let(:job_execution) { JobExecution.new(reference, job) }

  let(:stage_production) { stages(:test_production) }
  let(:job_production) { project.jobs.create!(user: user, command: "foo", status: "succeeded") }

  it "creates a new deploy" do
    count = Deploy.count
    service.deploy!(stage, reference)
    assert_equal count + 1, Deploy.count
  end

  describe "before notifications" do
    it "sends flowdock notifications if the stage has flows" do
      stage.stubs(:send_flowdock_notifications?).returns(true)
      FlowdockNotification.any_instance.expects(:deliver)
      service.deploy!(stage, reference)
    end
  end

  describe "after notifications" do
    before do
      stage.stubs(:create_deploy).returns(deploy)
      deploy.stubs(:persisted?).returns(true)
      job_execution.stubs(:execute!)

      JobExecution.stubs(:start_job).with(reference, deploy.job).returns(job_execution)
    end

    it "sends email notifications if the stage has email addresses" do
      stage.stubs(:send_email_notifications?).returns(true)

      DeployMailer.expects(:deploy_email).returns( stub("DeployMailer", :deliver => true) )

      service.deploy!(stage, reference)
      job_execution.run!
    end

    it "sends flowdock notifications if the stage has flows" do
      stage.stubs(:send_flowdock_notifications?).returns(true)

      FlowdockNotification.any_instance.expects(:deliver).at_least_once

      service.deploy!(stage, reference)
      job_execution.run!
    end

    it "sends datadog notifications if the stage has datadog tags" do
      stage.stubs(:send_datadog_notifications?).returns(true)

      DatadogNotification.any_instance.expects(:deliver)

      service.deploy!(stage, reference)
      job_execution.run!
    end

    it "sends github notifications if the stage has it enabled and deploy succeeded" do
      stage.stubs(:send_github_notifications?).returns(true)
      deploy.stubs(:status).returns("succeeded")

      GithubNotification.any_instance.expects(:deliver)

      service.deploy!(stage, reference)
      job_execution.run!
    end

    it "does not send github notifications if the stage has it enabled and deploy failed" do
      stage.stubs(:send_github_notifications?).returns(true)
      deploy.stubs(:status).returns("failed")

      GithubNotification.any_instance.expects(:deliver).never

      service.deploy!(stage, reference)
      job_execution.run!
    end
  end
end
