require_relative '../test_helper'

describe DeployService do
  let(:project) { deploy.project }
  let(:user) { job.user }
  let(:other_user) { users(:deployer) }
  let(:service) { DeployService.new(user) }
  let(:stage) { deploy.stage }
  let(:job) { jobs(:succeeded_test) }
  let(:deploy) { deploys(:succeeded_test) }
  let(:reference) { deploy.reference }
  let(:job_execution) { JobExecution.new(reference, job) }

  let(:stage_production_1) { stages(:test_production) }
  let(:stage_production_2) { stages(:test_production_pod) }

  let (:ref1) { "v1" }

  describe "#deploy!" do
    it "starts a deploy" do
      SseRailsEngine.expects(:send_event).twice
      assert_difference "Job.count", +1 do
        assert_difference "Deploy.count", +1 do
          service.deploy!(stage, reference: reference)
        end
      end
    end

    describe "when buddy check is needed" do
      before { BuddyCheck.stubs(:enabled?).returns(true) }
      let(:deploy) { deploys(:succeeded_production_test) }

      def create_previous_deploy(ref, stage, successful: true)
        job = project.jobs.create!(user: user, command: "foo", status: successful ? "succeeded" : 'failed')
        Deploy.create!(job: job, reference: ref, stage: stage, buddy: other_user, started_at: Time.now)
      end

      it "does not start the deploy" do
        service.expects(:confirm_deploy!).never
        service.deploy!(stage, reference: reference)
      end

      describe "if release is approved" do
        before { create_previous_deploy(ref1, stage_production_1) }

        it "starts the deploy, if in grace period" do
          service.expects(:confirm_deploy!).once
          service.deploy!(stage_production_2, reference: ref1)
        end

        it "does not start the deploy, if past grace period" do
          service.expects(:confirm_deploy!).never
          travel BuddyCheck.grace_period + 1.minute do
            service.deploy!(stage_production_2, reference: ref1)
          end
        end
      end

      describe "if similar deploy was bypassed" do
        before { service.stubs(:bypassed?).returns(true) }
        it "does not start the deploy" do
          service.expects(:release_approved?).once
          service.expects(:confirm_deploy!).never
          service.deploy!(stage, reference: reference)
        end
      end

      describe "if similar deploy was approved" do
        before do
          service.stubs(:bypassed?).returns(false)
          service.stubs(:latest_approved_deploy).returns(Deploy.new(id:22, buddy:other_user) )
        end
        it "it starts the deploy" do
          service.expects(:confirm_deploy!).once
          service.deploy!(stage, reference: reference)
        end
      end

      describe "if deploy groups are enabled" do
        before do
          DeployGroup.stubs(:enabled?).returns(true)
          stage.update_attribute(:production, false)
        end

        it 'should deploy because of prod deploy groups' do
          create_previous_deploy(ref1, stage_production_1)
          service.expects(:confirm_deploy!).once
          service.deploy!(stage_production_2, reference: ref1)
        end

        it 'should not deploy if previous deploy was not on prod' do
          create_previous_deploy(ref1, stages(:test_staging))
          service.expects(:confirm_deploy!).never
          service.deploy!(stage_production_2, reference: ref1)
        end
      end
    end
  end

  describe "#confirm_deploy!" do
    it "starts a job execution" do
      JobExecution.expects(:start_job).returns(mock).once
      service.confirm_deploy!(deploy)
    end

    describe "when buddy check is needed" do
      before do
        stage.stubs(:deploy_requires_approval?).returns(true)
      end

      it "starts a job execution" do
        stub_request(:get, "https://api.github.com/repos/bar/foo/compare/staging...staging")
        JobExecution.expects(:start_job).returns(mock).once
        DeployMailer.expects(:bypass_email).never
        deploy.buddy = other_user
        service.confirm_deploy!(deploy)
      end

      it "reports bypass via mail" do
        stub_request(:get, "https://api.github.com/repos/bar/foo/compare/staging...staging")
        JobExecution.expects(:start_job).returns(mock).once
        DeployMailer.expects(bypass_email: stub(deliver_now: true))
        deploy.buddy = user
        service.confirm_deploy!(deploy)
      end
    end
  end

  describe "before notifications" do
    it "sends before_deploy hook" do
      record_hooks(:before_deploy) do
        service.deploy!(stage, reference: reference)
      end.must_equal [[Deploy.first, nil]]
    end

    it "creates a github deployment" do
      deployment = stub

      stage.stubs(:use_github_deployment_api?).returns(true)

      GithubDeployment.stubs(new: deployment)
      deployment.expects(:create_github_deployment)

      service.deploy!(stage, reference: reference)
    end
  end

  describe "after notifications" do
    before do
      SseRailsEngine.expects(:send_event).with('deploys', { type: 'finish' }).never
      stage.stubs(:create_deploy).returns(deploy)
      deploy.stubs(:persisted?).returns(true)
      job_execution.stubs(:execute!)

      JobExecution.stubs(:new).returns(job_execution)
    end

    it "sends email notifications if the stage has email addresses" do
      stage.stubs(:send_email_notifications?).returns(true)

      DeployMailer.expects(:deploy_email).returns( stub("DeployMailer", deliver_now: true) )

      service.deploy!(stage, reference: reference)
      job_execution.send(:run!)
    end

    it "sends after_deploy hook" do
      record_hooks(:after_deploy) do
        service.deploy!(stage, reference: reference)
        job_execution.send(:run!)
      end.must_equal [[deploy, nil]]
    end

    it "sends datadog notifications if the stage has datadog tags" do
      stage.stubs(:send_datadog_notifications?).returns(true)

      DatadogNotification.any_instance.expects(:deliver)

      service.deploy!(stage, reference: reference)
      job_execution.send(:run!)
    end

    it "sends github notifications if the stage has it enabled and deploy succeeded" do
      stage.stubs(:send_github_notifications?).returns(true)
      deploy.stubs(:status).returns("succeeded")

      GithubNotification.any_instance.expects(:deliver)

      service.deploy!(stage, reference: reference)
      job_execution.send(:run!)
    end

    it "does not send github notifications if the stage has it enabled and deploy failed" do
      stage.stubs(:send_github_notifications?).returns(true)
      deploy.stubs(:status).returns("failed")

      GithubNotification.any_instance.expects(:deliver).never

      service.deploy!(stage, reference: reference)
      job_execution.send(:run!)
    end

    it "updates a github deployment status" do
      deployment = stub(create_github_deployment: deployment)

      stage.stubs(:use_github_deployment_api?).returns(true)

      GithubDeployment.stubs(new: deployment)
      deployment.expects(:update_github_deployment_status)

      service.deploy!(stage, reference: reference)
      job_execution.send(:run!)
    end

    it "email notification for failed deploys" do
      stage.stubs(:automated_failure_emails).returns(["foo@bar.com"])

      DeployMailer.expects(:deploy_failed_email).returns( stub("DeployMailer", deliver_now: true) )

      service.deploy!(stage, reference: reference)
      job_execution.send(:run!)
    end
  end
end
