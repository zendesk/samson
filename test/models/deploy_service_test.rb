# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 4

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
      DeployNotificationsChannel.expects(:broadcast).with(1).times(2)
      assert_difference "Job.count", +1 do
        assert_difference "Deploy.count", +1 do
          service.deploy(stage, reference: reference)
        end
      end
    end

    describe "when buddy check is needed" do
      before { Samson::BuddyCheck.stubs(:enabled?).returns(true) }
      let(:deploy) { deploys(:succeeded_production_test) }

      def create_previous_deploy(ref, stage, succeeded: true, bypassed: false, commit: nil)
        status = succeeded ? "succeeded" : 'failed'
        job = project.jobs.create!(user: user, command: "foo", status: status, commit: commit)
        buddy = bypassed ? user : other_user
        Deploy.create!(job: job, reference: ref, stage: stage, buddy: buddy, started_at: Time.now, project: project)
      end

      it "does not start the deploy" do
        Samson::Hooks.expects(:fire).with(:buddy_request, anything)
        service.expects(:confirm_deploy).never
        service.deploy(stage, reference: reference)
      end

      describe "similar deploy was approved" do
        before { travel(-1.minute) { create_previous_deploy(ref1, stage_production_1) } }

        it "starts the deploy, if in grace period" do
          service.expects(:confirm_deploy)
          service.deploy(stage_production_2, reference: ref1)
        end

        it "does not start the deploy, if past grace period" do
          service.expects(:confirm_deploy).never
          travel Samson::BuddyCheck.grace_period + 1.minute do
            service.deploy(stage_production_2, reference: ref1)
          end
        end

        describe "when stage was modified after the similar deploy" do
          before { stage.audits.create!(action: 'update', audited_changes: {"script" => ["foo", "bar"]}) }

          it "does not start the deploy" do
            service.expects(:confirm_deploy).never
            service.deploy(stage_production_2, reference: ref1)
          end

          it "starts the deploy when stage was modified after an older similar deploy" do
            Deploy.first.update_column(:started_at, 4.seconds.from_now)
            create_previous_deploy(ref1, stage_production_1)
            service.expects(:confirm_deploy)
            service.deploy(stage_production_2, reference: ref1)
          end
        end
      end

      describe "if similar deploy was bypassed" do
        it "does not start the deploy" do
          create_previous_deploy(ref1, stage_production_1, bypassed: true)
          service.expects(:confirm_deploy).never
          service.deploy(stage_production_2, reference: ref1)
        end
      end

      describe "similar deploy reference with different commit sha" do
        it "does not start the deploy" do
          create_previous_deploy(ref1, stage_production_1, commit: 'xyz')
          Changeset.any_instance.expects(:commits).returns(['xyz'])
          service.expects(:confirm_deploy).never
          service.deploy(stage_production_1, reference: ref1)
        end
      end

      describe "if deploy groups are enabled" do
        before do
          DeployGroup.stubs(:enabled?).returns(true)
          stage.update_attribute(:production, false)
        end

        it 'deploys because of prod deploy groups' do
          create_previous_deploy(ref1, stage_production_1)
          service.expects(:confirm_deploy).once
          service.deploy(stage_production_2, reference: ref1)
        end

        it 'does not deploy if previous deploy was not on prod' do
          create_previous_deploy(ref1, stages(:test_staging))
          service.expects(:confirm_deploy).never
          service.deploy(stage_production_2, reference: ref1)
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

        JobQueue.expects(:queued?).with(deploy_two.job.id).returns(true)
        JobQueue.expects(:dequeue).with(deploy_two.job.id).returns(true)

        service.deploy(stage, reference: reference)

        deploy_one.job.reload.status.must_equal 'running'
        deploy_two.job.reload.status.must_equal 'cancelled'
      end

      it "does not cancel queued deploys for other users" do
        deploy_one = create_deployment(other_user, 'v1', stage, 'running')
        deploy_two = create_deployment(other_user, 'v2', stage, 'pending')

        service.deploy(stage, reference: reference)

        deploy_one.job.reload.status.must_equal 'running'
        deploy_two.job.reload.status.must_equal 'pending'
      end
    end
  end

  describe "#confirm_deploy!" do
    it "starts a job execution" do
      JobQueue.expects(:perform_later).returns(mock).once
      service.confirm_deploy(deploy)
    end

    describe "when stage can run in parallel" do
      before do
        stage.stubs(:run_in_parallel).returns true
      end

      it "immediately starts the job" do
        job_execution
        JobExecution.stubs(:new).returns(job_execution)
        JobQueue.expects(:perform_later).with(job_execution, queue: nil)
        deploy.buddy = user
        service.confirm_deploy(deploy)
      end
    end

    describe "when stage can't run in parallel" do
      it "will be queued on the stage id" do
        job_execution
        JobExecution.stubs(:new).returns(job_execution)
        JobQueue.expects(:perform_later).with(job_execution, queue: "stage-#{stage.id}")
        deploy.buddy = user
        service.confirm_deploy(deploy)
      end
    end

    describe "when buddy check is needed" do
      before do
        stage.stubs(:deploy_requires_approval?).returns(true)

        job_execution.stubs(:execute)
        job_execution.stubs(:setup).returns(true)

        JobExecution.stubs(:new).returns(job_execution)
        JobQueue.any_instance.stubs(:delete_and_enqueue_next) # we do not properly add the job, so removal fails
      end

      it "starts a job execution" do
        JobQueue.expects(:perform_later).returns(mock).once
        DeployMailer.expects(:bypass_email).never
        deploy.buddy = other_user
        service.confirm_deploy(deploy)
      end

      it "reports bypass via mail" do
        JobQueue.expects(:perform_later).returns(mock).once
        DeployMailer.expects(bypass_email: stub(deliver_now: true))
        deploy.buddy = user
        service.confirm_deploy(deploy)
        job_execution.perform
      end
    end
  end

  describe "start callbacks" do
    before do
      stage.stubs(:create_deploy).returns(deploy)
      deploy.stubs(:persisted?).returns(true)
      job_execution.stubs(:execute)
      job_execution.stubs(:setup).returns(true)

      JobExecution.stubs(:new).returns(job_execution)
      JobQueue.any_instance.stubs(:delete_and_enqueue_next) # we do not properly add the job, so removal fails
    end

    it "sends before_deploy hook" do
      record_hooks(:before_deploy) do
        service.deploy(stage, reference: reference)
        job_execution.perform
      end.map(&:first).must_equal [deploy]
    end
  end

  describe "finish callbacks" do
    def run_deploy
      service.deploy(stage, reference: reference)
      job_execution.perform
    end

    before do
      stage.stubs(:create_deploy).returns(deploy)
      deploy.stubs(:persisted?).returns(true)
      job_execution.stubs(:execute)
      job_execution.stubs(:setup).returns(true)

      JobExecution.stubs(:new).returns(job_execution)
      JobQueue.any_instance.stubs(:delete_and_enqueue_next) # we do not properly add the job, so removal fails
    end

    describe "with email notifications setup" do
      before { stage.notify_email_address = 'a@b.com;b@c.com' }

      it "sends email notifications if the stage has email addresses" do
        DeployMailer.expects(:deploy_email).with(anything, ['a@b.com', 'b@c.com']).
          returns(stub("DeployMailer", deliver_now: true))
        run_deploy
      end

      it "does not fail all callbacks when 1 callback fails" do
        service.stubs(:send_deploy_update) # other callbacks
        service.expects(:send_deploy_update).with(finished: true).raises # last callback
        Samson::ErrorNotifier.expects(:notify)
        DeployMailer.expects(:deploy_email).returns(stub(deliver_now: true))
        run_deploy
      end
    end

    it "sends after_deploy hook" do
      record_hooks(:after_deploy) { run_deploy }.map(&:first).must_equal [deploy]
    end

    it "email notification for failed deploys" do
      stage.stubs(:automated_failure_emails).returns(["foo@bar.com"])

      DeployMailer.expects(:deploy_failed_email).returns(stub("DeployMailer", deliver_now: true))

      run_deploy
    end

    describe "with redeploy_previous_when_failed" do
      def run_deploy(redeploy)
        service.deploy(stage, reference: reference)
        service.expects(:deploy).capture(deploy_args).times(redeploy ? 1 : 0).returns(deploy) # stub to avoid loops
        job_execution.perform
      end

      let(:deploy_args) { [] }

      before do
        service # cache instance
        deploy.redeploy_previous_when_failed = true
        deploy.stubs(:previous_succeeded_deploy).returns(deploys(:succeeded_production_test))
        Job.any_instance.stubs(:status).returns("failed")
      end

      it "redeploys previous if deploy failed" do
        run_deploy true
        deploy_args.dig(0, 1, :reference).must_equal "v1.0"
      end

      it "does nothing when it cannot find a previous deploy" do
        deploy.unstub(:previous_succeeded_deploy)
        deploy.expects(:previous_succeeded_deploy).returns(nil)
        run_deploy false
      end

      it "does not deploy previous if deploy succeeds" do
        Job.any_instance.unstub(:status)
        run_deploy false
      end

      it "uses short sha if not a versioned release" do
        deploys(:succeeded_production_test).update_column(:reference, 'master')
        run_deploy true
        deploy_args.dig(0, 1, :reference).must_equal "abcabca"
      end
    end
  end

  describe "#update_average_deploy_time" do
    it 'updates stage average_deploy_time with new duration' do
      stage.update_column(:average_deploy_time, 3.00)

      new_deploy = Deploy.create!(deploy.attributes.except('id', 'created_at', 'updated_at'))
      new_deploy.expects(:duration).returns(4.0)

      service.send(:update_average_deploy_time, new_deploy)

      stage.reload
      assert_in_delta 3.33, stage.average_deploy_time, 0.004
    end

    it 'handles no previous average' do
      stage.deploys.where.not(id: deploy.id).delete_all
      stage.average_deploy_time.must_be_nil

      deploy.expects(:duration).returns(4.0)

      service.send(:update_average_deploy_time, deploy)

      stage.reload
      assert_in_delta 4.0, stage.average_deploy_time
    end
  end
end
