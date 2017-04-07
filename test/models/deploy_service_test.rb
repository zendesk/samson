# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

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

  let(:ref1) { "v1" }

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

      def create_previous_deploy(ref, stage, successful: true, bypassed: false)
        job = project.jobs.create!(user: user, command: "foo", status: successful ? "succeeded" : 'failed')
        buddy = bypassed ? user : other_user
        Deploy.create!(job: job, reference: ref, stage: stage, buddy: buddy, started_at: Time.now, project: project)
      end

      it "does not start the deploy" do
        service.expects(:confirm_deploy!).never
        service.deploy!(stage, reference: reference)
      end

      describe "similar deploy was approved" do
        before { travel(-1.minute) { create_previous_deploy(ref1, stage_production_1) } }

        it "starts the deploy, if in grace period" do
          service.expects(:confirm_deploy!)
          service.deploy!(stage_production_2, reference: ref1)
        end

        it "does not start the deploy, if past grace period" do
          service.expects(:confirm_deploy!).never
          travel BuddyCheck.grace_period + 1.minute do
            service.deploy!(stage_production_2, reference: ref1)
          end
        end

        describe "when stage was modified after the similar deploy" do
          let!(:version) { stage.versions.create!(event: 'Update') }

          it "does not start the deploy" do
            service.expects(:confirm_deploy!).never
            service.deploy!(stage_production_2, reference: ref1)
          end

          it "starts the deploy when stage was modified after an older similar deploy" do
            Deploy.first.update_column(:started_at, 4.seconds.from_now)
            create_previous_deploy(ref1, stage_production_1)
            service.expects(:confirm_deploy!)
            service.deploy!(stage_production_2, reference: ref1)
          end
        end
      end

      describe "if similar deploy was bypassed" do
        it "does not start the deploy" do
          create_previous_deploy(ref1, stage_production_1, bypassed: true)
          service.expects(:confirm_deploy!).never
          service.deploy!(stage_production_2, reference: ref1)
        end
      end

      describe "if deploy groups are enabled" do
        before do
          DeployGroup.stubs(:enabled?).returns(true)
          stage.update_attribute(:production, false)
        end

        it 'deploys because of prod deploy groups' do
          create_previous_deploy(ref1, stage_production_1)
          service.expects(:confirm_deploy!).once
          service.deploy!(stage_production_2, reference: ref1)
        end

        it 'does not deploy if previous deploy was not on prod' do
          create_previous_deploy(ref1, stages(:test_staging))
          service.expects(:confirm_deploy!).never
          service.deploy!(stage_production_2, reference: ref1)
        end
      end
    end

    describe "when cancelling queued deploys" do
      before do
        stage.stubs(:cancel_queued_deploys?).returns true
      end

      def create_deployment(user, ref, stage, status)
        job = project.jobs.create!(user: user, command: "foo", status: status)
        Deploy.create!(job: job, reference: ref, stage: stage, started_at: Time.now, project: project)
      end

      it "cancels existing queued deploys for that user" do
        deploy_one = create_deployment(user, 'v1', stage, 'running')
        deploy_two = create_deployment(user, 'v2', stage, 'pending')

        JobExecution.expects(:queued?).with(deploy_two.job.id).returns(true)
        JobExecution.expects(:dequeue).with(deploy_two.job.id).returns(true)

        service.deploy!(stage, reference: reference)

        deploy_one.job.reload.status.must_equal 'running'
        deploy_two.job.reload.status.must_equal 'cancelled'
      end

      it "does not cancel queued deploys for other users" do
        deploy_one = create_deployment(other_user, 'v1', stage, 'running')
        deploy_two = create_deployment(other_user, 'v2', stage, 'pending')

        service.deploy!(stage, reference: reference)

        deploy_one.job.reload.status.must_equal 'running'
        deploy_two.job.reload.status.must_equal 'pending'
      end
    end
  end

  describe "#confirm_deploy!" do
    it "starts a job execution" do
      JobExecution.expects(:start_job).returns(mock).once
      service.confirm_deploy!(deploy)
    end

    describe "when stage can run in parallel" do
      before do
        stage.stubs(:run_in_parallel).returns true
      end

      it "immediately starts the job" do
        job_execution
        JobExecution.stubs(:new).returns(job_execution)
        JobExecution.expects(:start_job).with(job_execution, queue: nil)
        deploy.buddy = user
        service.confirm_deploy!(deploy)
      end
    end

    describe "when stage can't run in parallel" do
      it "will be queued on the stage id" do
        job_execution
        JobExecution.stubs(:new).returns(job_execution)
        JobExecution.expects(:start_job).with(job_execution, queue: "stage-#{stage.id}")
        deploy.buddy = user
        service.confirm_deploy!(deploy)
      end
    end

    describe "when buddy check is needed" do
      before do
        stage.stubs(:deploy_requires_approval?).returns(true)

        job_execution.stubs(:execute!)
        job_execution.stubs(:setup!).returns(true)

        JobExecution.stubs(:new).returns(job_execution)
        JobQueue.any_instance.stubs(:delete_and_enqueue_next) # we do not properly add the job, so removal fails
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
        job_execution.send(:run!)
      end
    end
  end

  describe "before notifications" do
    before do
      stage.stubs(:create_deploy).returns(deploy)
      deploy.stubs(:persisted?).returns(true)
      job_execution.stubs(:execute!)
      job_execution.stubs(:setup!).returns(true)

      JobExecution.stubs(:new).returns(job_execution)
      JobQueue.any_instance.stubs(:delete_and_enqueue_next) # we do not properly add the job, so removal fails
    end

    it "sends before_deploy hook" do
      record_hooks(:before_deploy) do
        service.deploy!(stage, reference: reference)
        job_execution.send(:run!)
      end.must_equal [[deploy, nil]]
    end
  end

  describe "after notifications" do
    before do
      SseRailsEngine.expects(:send_event).with('deploys', type: 'finish').never
      stage.stubs(:create_deploy).returns(deploy)
      deploy.stubs(:persisted?).returns(true)
      job_execution.stubs(:execute!)
      job_execution.stubs(:setup!).returns(true)

      JobExecution.stubs(:new).returns(job_execution)
      JobQueue.any_instance.stubs(:delete_and_enqueue_next) # we do not properly add the job, so removal fails
    end

    describe "with email notifications setup" do
      before { stage.notify_email_address = 'a@b.com;b@c.com' }

      it "sends email notifications if the stage has email addresses" do
        DeployMailer.expects(:deploy_email).with(anything, ['a@b.com', 'b@c.com']).
          returns(stub("DeployMailer", deliver_now: true))

        service.deploy!(stage, reference: reference)
        job_execution.send(:run!)
      end

      it "does not fail all callbacks when 1 callback fails" do
        service.stubs(:send_sse_deploy_update)
        service.expects(:send_sse_deploy_update).with('finish', anything).raises # first callback
        Airbrake.expects(:notify)
        DeployMailer.expects(:deploy_email).returns(stub(deliver_now: true))
        service.deploy!(stage, reference: reference)
        job_execution.send(:run!)
      end
    end

    it "sends after_deploy hook" do
      record_hooks(:after_deploy) do
        service.deploy!(stage, reference: reference)
        job_execution.send(:run!)
      end.must_equal [[deploy, nil]]
    end

    it "email notification for failed deploys" do
      stage.stubs(:automated_failure_emails).returns(["foo@bar.com"])

      DeployMailer.expects(:deploy_failed_email).returns(stub("DeployMailer", deliver_now: true))

      service.deploy!(stage, reference: reference)
      job_execution.send(:run!)
    end
  end
end
