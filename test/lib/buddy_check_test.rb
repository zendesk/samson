# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 5

# TODO: full converage and move deploy related tests into deploy
describe BuddyCheck do
  let(:project) { job.project }
  let(:user) { job.user }
  let(:service) { DeployService.new(user) }
  let(:stage) { deploy.stage }
  let(:reference) { deploy.reference }
  let(:job) { jobs(:succeeded_test) }
  let(:deploy) { deploys(:succeeded_production_test) }
  let(:job_execution) { JobExecution.new(reference, job) }

  let(:other_user) { users(:deployer_buddy) }

  it "buddy is set for buddy_checked deploy" do
    deploy_rtn = stage.create_deploy(user, reference: reference)
    deploy_rtn.confirm_buddy!(other_user)
    deploy_rtn.buddy.must_equal other_user
  end

  it "does not deploy production if buddy check is enabled" do
    BuddyCheck.stubs(:enabled?).returns(true)

    stage.expects(:production?).returns(true)
    service.expects(:confirm_deploy!).never

    service.deploy!(stage, reference: reference)
  end

  it "does deploy production if buddy check is not enabled" do
    BuddyCheck.stubs(:enabled?).returns(false)

    stage.stubs(:production?).returns(true)
    service.expects(:confirm_deploy!).once

    service.deploy!(stage, reference: reference)
  end

  it "does deploy non-production if buddy check is enabled" do
    BuddyCheck.stubs(:enabled?).returns(true)

    stage.expects(:production?).returns(false)
    service.expects(:confirm_deploy!).once

    service.deploy!(stage, reference: reference)
  end

  it "does deploy non-production if buddy check is not enabled" do
    BuddyCheck.stubs(:enabled?).returns(false)

    stage.stubs(:production?).returns(false)
    service.expects(:confirm_deploy!).once

    service.deploy!(stage, reference: reference)
  end

  describe "before notifications, buddycheck enabled" do
    before do
      stage.update_attribute(:production, true)
      job_execution.stubs(:execute!)
      job_execution.stubs(:setup!).returns(true)

      JobExecution.stubs(:new).returns(job_execution)
      JobQueue.any_instance.stubs(:delete_and_enqueue_next) # we do not properly add the job, so removal fails

      BuddyCheck.stubs(:enabled?).returns(true)
    end

    describe "for buddy same" do
      it "sends bypass alert email notification" do
        DeployMailer.stubs(:prepare_mail)

        DeployMailer.expects(:bypass_email).returns(stub("DeployMailer", deliver_now: true))

        deploy.buddy = user
        service.confirm_deploy!(deploy)
        job_execution.send(:run!)
      end
    end

    describe "for buddy different" do
      it "does not send bypass alert email notification" do
        DeployMailer.expects(:bypass_email).never

        deploy.buddy = other_user
        service.confirm_deploy!(deploy)
        job_execution.send(:run!)
      end
    end
  end

  describe "before notifications, buddycheck disabled" do
    before do
      job_execution.stubs(:execute!)
      JobExecution.expects(:start_job).returns(job_execution)
      job_execution.stubs(:setup!).returns(true)

      BuddyCheck.stubs(:enabled?).returns(false)
    end

    describe "for buddy same" do
      it "sends bypass alert email notification" do
        DeployMailer.expects(:bypass_email).never

        deploy.buddy = user
        service.confirm_deploy!(deploy)
        job_execution.send(:run!)
      end
    end

    describe "for buddy different" do
      it "does not send bypass alert email notification" do
        DeployMailer.expects(:bypass_email).never

        deploy.buddy = other_user
        service.confirm_deploy!(deploy)
        job_execution.send(:run!)
      end
    end
  end
end
