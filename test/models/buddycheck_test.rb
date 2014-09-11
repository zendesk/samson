require_relative '../test_helper'

class BuddyCheckDeployServiceTest < ActiveSupport::TestCase
  let(:project) { projects(:test) }
  let(:user) { users(:deployer) }
  let(:service) { DeployService.new(project, user) }
  let(:stage) { stages(:test_staging) }
  let(:reference) { "staging" }
  let(:job) { project.jobs.create!(user: user, command: "foo", status: "succeeded") }
  let(:deploy) { stub(user: user, job: job, changeset: "changeset") }
  let(:job_execution) { JobExecution.new(reference, job) }

  let(:buddy_same) { user }
  let(:buddy_other) { users(:deployer_buddy) }

  it "start_time is set for buddy_checked deploy" do
    deploy_rtn = stage.create_deploy(reference: reference, user: user)
    deploy_rtn.confirm_buddy!(buddy_other)

    assert_equal true, deploy_rtn.start_time.to_i > 0
  end

  it "start_time is set for non-buddy_checked deploy" do
    deploy_rtn = stage.create_deploy(reference: reference, user: user)

    assert_equal true, deploy_rtn.start_time.to_i > 0
  end

  it "does not deploy production if buddy check is enabled" do
    BuddyCheck.stubs(:enabled?).returns(true)

    stage.production = true
    service.expects(:confirm_deploy!).never

    service.deploy!(stage, reference)
  end

  it "does deploy production if buddy check is not enabled" do
    BuddyCheck.stubs(:enabled?).returns(false)

    stage.production = true
    service.expects(:confirm_deploy!).once

    service.deploy!(stage, reference)
  end

  it "does deploy non-production if buddy check is enabled" do
    BuddyCheck.stubs(:enabled?).returns(true)

    stage.production = false
    service.expects(:confirm_deploy!).once

    service.deploy!(stage, reference)
  end

  it "does deploy non-production if buddy check is not enabled" do
    BuddyCheck.stubs(:enabled?).returns(false)

    stage.production = false
    service.expects(:confirm_deploy!).once

    service.deploy!(stage, reference)
  end

  describe "before notifications, buddycheck enabled" do
    before do
      job_execution.stubs(:execute!)
      JobExecution.stubs(:start_job).with(reference, deploy.job).returns(job_execution)

      BuddyCheck.stubs(:enabled?).returns(true)
    end

    describe "for buddy same" do
      it "sends bypass alert email notification" do
        DeployMailer.stubs(:prepare_mail)

        DeployMailer.expects(:bypass_email).returns( stub("DeployMailer", :deliver => true) )

        service.confirm_deploy!(deploy, stage, reference, buddy_same)
        job_execution.run!
      end
    end

    describe "for buddy different" do
      it "does not send bypass alert email notification" do

        DeployMailer.expects(:bypass_email).never

        service.confirm_deploy!(deploy, stage, reference, buddy_other)
        job_execution.run!
      end
    end
  end

  describe "before notifications, buddycheck disabled" do
    before do
      job_execution.stubs(:execute!)
      JobExecution.stubs(:start_job).with(reference, deploy.job).returns(job_execution)

      BuddyCheck.stubs(:enabled?).returns(false)
    end

    describe "for buddy same" do
      it "sends bypass alert email notification" do
        DeployMailer.expects(:bypass_email).never

        service.confirm_deploy!(deploy, stage, reference, buddy_same)
        job_execution.run!
      end
    end

    describe "for buddy different" do
      it "does not send bypass alert email notification" do

        DeployMailer.expects(:bypass_email).never

        service.confirm_deploy!(deploy, stage, reference, buddy_other)
        job_execution.run!
      end
    end
  end

end
