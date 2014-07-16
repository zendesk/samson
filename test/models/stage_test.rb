require_relative '../test_helper'

describe Stage do
  subject { stages(:test_staging) }

  describe '#command' do
    describe 'adding a built command' do
      before do
        subject.stage_commands.build(command:
          Command.new(command: 'test')
        )

        subject.command_ids = [commands(:echo).id]
        subject.save!
        subject.reload
      end

      it 'add new command to the end' do
        subject.command.must_equal("#{commands(:echo).command}\ntest")
      end
    end

    describe 'adding + sorting a command' do
      before do
        command = Command.create!(command: 'test')

        subject.command_ids = [command.id, commands(:echo).id]
        subject.save!
        subject.reload
      end

      it 'joins all commands based on position' do
        subject.command.must_equal("test\n#{commands(:echo).command}")
      end
    end

    describe 'no commands' do
      before { subject.commands.clear }

      it 'is empty' do
        subject.command.must_be_empty
      end
    end
  end

  describe "#current_release?" do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }
    let(:author) { users(:deployer) }
    let(:job) { project.jobs.create!(user: author, commit: "x", command: "echo", status: "succeeded") }

    let(:previous_release) { project.releases.create!(version: "v3", author: author, commit: "A") }
    let(:last_release) { project.releases.create!(version: "v4", author: author, commit: "B") }
    let(:undeployed_release) { project.releases.create!(version: "v5", author: author, commit: "C") }

    before do
      stage.deploys.create!(reference: "v3", job: job)
      stage.deploys.create!(reference: "v4", job: job)
    end

    it "returns true if the release was the last thing deployed to the stage" do
      assert stage.current_release?(last_release)
    end

    it "returns false if the release is not the last thing deployed to the stage" do
      refute stage.current_release?(previous_release)
    end

    it "returns false if the release has never been deployed to the stage" do
      refute stage.current_release?(undeployed_release)
    end
  end

  describe "#create_deploy" do
    let(:user) { users(:deployer) }

    it "creates a new deploy" do
      deploy = subject.create_deploy(reference: "foo", user: user)
      deploy.reference.must_equal "foo"
    end

    it "creates a new job" do
      deploy = subject.create_deploy(reference: "foo", user: user)
      deploy.job.user.must_equal user
    end

    it "creates neither job nor deploy if one fails to save" do
      assert_no_difference "Deploy.count + Job.count" do
        subject.create_deploy(reference: "", user: user)
      end
    end
  end

  describe "#notify_email_addresses" do
    it "returns email addresses separated by a semicolon" do
      stage = Stage.new(notify_email_address: "a@foo.com; b@foo.com")
      stage.notify_email_addresses.must_equal ["a@foo.com", "b@foo.com"]
    end
  end

  describe '#all_commands' do
    describe 'with commands' do
      before do
        Command.create!(command: 'test')
      end

      it 'includes all commands, sorted' do
        subject.all_commands.must_equal(subject.commands + Command.global)
      end
    end

    describe 'no commands' do
      let(:project) { projects(:test) }
      subject { project.stages.build }

      it 'includes all commands' do
        subject.all_commands.must_equal(Command.for_project(project))
      end
    end

    describe 'no project' do
      subject { Stage.new }

      it 'includes all commands' do
        subject.all_commands.must_equal(Command.global)
      end
    end
  end

  describe 'unlocked/locked?' do
    describe 'with a lock' do
      before do
        subject.create_lock!(user: users(:deployer))
      end

      it 'is not included' do
        Stage.unlocked.wont_include(subject)
      end

      it 'is locked?' do
        subject.reload.must_be(:locked?)
      end
    end

    describe 'with a global lock' do
      before do
        Lock.create!(user: users(:admin))
      end

      it 'is not empty' do
        Stage.unlocked.wont_be_empty
      end

      it 'is not locked' do
        subject.wont_be(:locked?)
      end
    end

    it 'includes unlocked stage' do
      Stage.unlocked.must_include(subject)
    end

    it 'is not locked' do
      subject.wont_be(:locked?)
    end
  end

  describe "#next_stage" do
    let(:project) { Project.new }
    let(:stage1) { Stage.new(project: project) }
    let(:stage2) { Stage.new(project: project) }

    before do
      project.stages = [stage1, stage2]
    end

    it "returns the next stage of the project" do
      stage1.next_stage.must_equal stage2
    end

    it "returns nil if the current stage is the last stage" do
      stage2.next_stage.must_be_nil
    end
  end

  describe "#datadog_tags" do
    it "returns an array of the tags" do
      subject.datadog_tags = " foo; bar; baz "
      subject.datadog_tags.must_equal ["foo", "bar", "baz"]
    end

    it "returns an empty array if no tags have been configured" do
      subject.datadog_tags = nil
      subject.datadog_tags.must_equal []
    end
  end

  describe "#send_datadog_notifications?" do
    it "returns true if the stage has a Datadog tag configured" do
      subject.datadog_tags = "env:beta"
      subject.send_datadog_notifications?.must_equal true
    end

    it "returns false if the stage does not have a Datadog tag configured" do
      subject.datadog_tags = nil
      subject.send_datadog_notifications?.must_equal false
    end
  end

  describe ".build_clone" do
    before do
      subject.notify_email_address = "test@test.ttt"
      subject.flowdock_flows = [FlowdockFlow.new(name: "test", token: "abcxyz", stage_id: subject.id)]
      subject.datadog_tags = "xyz:abc"
      subject.new_relic_applications = [NewRelicApplication.new(name: "test", stage_id: subject.id)]
      subject.save

      @clone = Stage.build_clone(subject)
    end

    it "returns an unsaved copy of the given stage with exactly the same everything except id" do
      assert_equal @clone.attributes, subject.attributes
    end

    it "copies over the flowdock flows" do
      assert_equal @clone.flowdock_flows.map(&:attributes), subject.flowdock_flows.map(&:attributes)
    end

    it "copies over the new relic applications" do
      assert_equal @clone.new_relic_applications.map(&:attributes), subject.new_relic_applications.map(&:attributes)
    end
  end
end
