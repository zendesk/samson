# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  subject { stages(:test_staging) }
  let(:stage) { subject }

  describe ".where_reference_being_deployed" do
    it "returns stages where the reference is currently being deployed" do
      project = projects(:test)
      stage = stages(:test_staging)
      author = users(:deployer)

      job = project.jobs.create!(user: author, commit: "a", command: "yes", status: "running")
      stage.deploys.create!(reference: "xyz", job: job)

      assert_equal [stage], Stage.where_reference_being_deployed("xyz")
    end
  end

  describe ".deployed_on_release" do
    it "returns stages with deploy_on_release" do
      stage.update_column(:deploy_on_release, true)
      Stage.deployed_on_release.must_equal [stage]
    end
  end

  describe '.reset_order' do
    let(:project) { projects(:test) }
    let(:stage1) { Stage.create!(project: project, name: 'stage1', order: 1) }
    let(:stage2) { Stage.create!(project: project, name: 'stage2', order: 2) }
    let(:stage3) { Stage.create!(project: project, name: 'stage3', order: 3) }

    it 'updates the order on stages' do
      Stage.reset_order [stage3.id, stage2.id, stage1.id]

      stage1.reload.order.must_equal 2
      stage2.reload.order.must_equal 1
      stage3.reload.order.must_equal 0
    end

    it 'succeeds even if a stages points to a deleted stage' do
      stage1.update! next_stage_ids: [stage3.id]
      stage3.soft_delete!

      Stage.reset_order [stage2.id, stage1.id]

      stage1.reload.order.must_equal 1
      stage2.reload.order.must_equal 0
    end
  end

  describe '#command' do
    describe 'adding a built command' do
      before do
        subject.command_associations.build(
          command: Command.new(command: 'test')
        )

        subject.command_ids = [commands(:echo).id]
        subject.save!
        subject.reload
      end

      it 'add new command to the end' do
        subject.script.must_equal("#{commands(:echo).command}\ntest")
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
        subject.script.must_equal("test\n#{commands(:echo).command}")
      end
    end

    describe 'no commands' do
      before { subject.commands.clear }

      it 'is empty' do
        subject.script.must_be_empty
      end
    end
  end

  describe '#last_deploy' do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }

    it 'caches nil' do
      stage
      ActiveRecord::Relation.any_instance.expects(:first).returns nil
      stage.last_deploy.must_equal nil
      ActiveRecord::Relation.any_instance.expects(:first).never
      stage.last_deploy.must_equal nil
    end

    it 'returns the last deploy for the stage' do
      job = project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'succeeded')
      stage.deploys.create!(reference: 'master', job: job)
      job = project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'failed')
      deploy = stage.deploys.create!(reference: 'master', job: job)
      assert_equal deploy, stage.last_deploy
    end
  end

  describe '#last_successful_deploy' do
    let(:project) { projects(:test) }

    it 'caches nil' do
      subject
      ActiveRecord::Relation.any_instance.expects(:first).returns nil
      stage.last_successful_deploy.must_equal nil
      ActiveRecord::Relation.any_instance.expects(:first).never
      stage.last_successful_deploy.must_equal nil
    end

    it 'returns the last successful deploy for the stage' do
      successful_job = project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'succeeded')
      stage.deploys.create!(reference: 'master', job: successful_job)
      project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'failed')
      deploy = stage.deploys.create!(reference: 'master', job: successful_job)
      assert_equal deploy, stage.last_successful_deploy
    end
  end

  describe "#current_release?" do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }
    let(:author) { users(:deployer) }
    let(:job) { project.jobs.create!(user: author, commit: "x", command: "echo", status: "succeeded") }
    let(:releases) { Array.new(3).map { project.releases.create!(author: author, commit: "A") } }

    before do
      stage.deploys.create!(reference: "v124", job: job)
      stage.deploys.create!(reference: "v125", job: job)
    end

    it "returns true if the release was the last thing deployed to the stage" do
      assert stage.current_release?(releases[1])
    end

    it "returns false if the release is not the last thing deployed to the stage" do
      refute stage.current_release?(releases[0])
    end

    it "returns false if the release has never been deployed to the stage" do
      refute stage.current_release?(releases[2])
    end
  end

  describe "#create_deploy" do
    let(:user) { users(:deployer) }

    it "creates a new deploy" do
      deploy = subject.create_deploy(user, reference: "foo")
      deploy.reference.must_equal "foo"
      deploy.release.must_equal true
    end

    it "creates a new job" do
      deploy = subject.create_deploy(user, reference: "foo")
      deploy.job.commit.must_equal "foo"
      deploy.job.user.must_equal user
    end

    it "creates neither job nor deploy if one fails to save" do
      assert_no_difference "Deploy.count + Job.count" do
        subject.create_deploy(user, reference: "")
      end
    end

    it "creates a no-release deploy when stage was configured to not deploy code" do
      subject.no_code_deployed = true
      deploy = subject.create_deploy(user, reference: "foo")
      deploy.release.must_equal false
    end
  end

  describe "#current_deploy" do
    it "is nil when not deploying" do
      subject.current_deploy.must_equal nil
    end

    it 'caches nil' do
      subject
      ActiveRecord::Relation.any_instance.expects(:first).returns nil
      subject.current_deploy.must_equal nil
      ActiveRecord::Relation.any_instance.expects(:first).never
      subject.current_deploy.must_equal nil
    end

    it "is there when deploying" do
      subject.deploys.first.job.update_column(:status, 'running')
      subject.current_deploy.must_equal subject.deploys.first
    end

    it "is there when waiting for buddy" do
      subject.deploys.first.job.update_column(:status, 'pending')
      subject.current_deploy.must_equal subject.deploys.first
    end
  end

  describe "#notify_email_addresses" do
    it "returns email addresses separated by a semicolon" do
      stage = Stage.new(notify_email_address: "a@foo.com; b@foo.com")
      stage.notify_email_addresses.must_equal ["a@foo.com", "b@foo.com"]
    end
  end

  describe 'unlocked_for/locked?/locked_for?' do
    describe 'with a lock' do
      before do
        subject.create_lock!(user: users(:deployer))
      end

      it 'is not included' do
        Stage.unlocked_for(users(:admin)).wont_include(subject)
      end

      it 'is locked?' do
        subject.reload.must_be(:locked?)
      end

      it 'locks other users out' do
        subject.reload.locked_for?(users(:admin)).must_equal true
      end

      it 'does not lock out the user who puts up the lock' do
        subject.reload.locked_for?(users(:deployer)).must_equal false
      end
    end

    describe 'with a global lock' do
      before do
        Lock.create!(user: users(:admin))
      end

      it 'is not empty' do
        Stage.unlocked_for(users(:admin)).wont_be_empty
      end

      it 'is not locked' do
        subject.wont_be(:locked?)
      end
    end

    it 'includes unlocked stage' do
      Stage.unlocked_for(users(:deployer)).must_include(subject)
    end

    it 'is not locked' do
      subject.wont_be(:locked?)
    end
  end

  describe "#warning?" do
    let!(:lock) { stage.create_lock!(user: users(:deployer), warning: true, description: 'X') }

    it "shows" do
      assert stage.warning?
    end

    it "does not show without lock" do
      lock.destroy!
      stage.reload
      refute stage.warning?
    end

    it "does not with normal lock" do
      lock.update_column(:warning, false)
      stage.reload
      refute stage.warning?
    end
  end

  describe "#currently_deploying?" do
    it "is false when not deploying" do
      stage.currently_deploying?.must_equal false
    end

    it "is true when deploying" do
      stage.deploys.first.job.update_column(:status, 'running')
      stage.currently_deploying?.must_equal true
    end
  end

  describe "#send_email_notifications?" do
    it "is false when there is no address" do
      refute stage.send_email_notifications?
    end

    it "is false when there is a blank address" do
      stage.notify_email_address = ''
      refute stage.send_email_notifications?
    end

    it "is true when there is an address" do
      stage.notify_email_address = 'a'
      assert stage.send_email_notifications?
    end
  end

  describe "#global_name" do
    it "shows projects name to so we see where this stage belongs" do
      stage.global_name.must_equal "Staging - Project"
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

  describe "#automated_failure_emails" do
    let(:user) { users(:super_admin) }
    let(:deploy) do
      deploy = subject.create_deploy(user, reference: "commita")
      deploy.job.fail!
      deploy
    end
    let(:previous_deploy) { deploys(:succeeded_test) }
    let(:emails) { subject.automated_failure_emails(deploy) }
    let(:simple_response) { Hashie::Mash.new(commits: [{commit: {author: {email: "pete@example.com"}}}]) }

    before do
      user.update_attribute(:integration, true)
      subject.update_column(:static_emails_on_automated_deploy_failure, "static@example.com")
      subject.update_column(:email_committers_on_automated_deploy_failure, true)
      deploys(:failed_staging_test).destroy # this fixture confuses these tests.
    end

    it "includes static emails and committer emails" do
      GITHUB.expects(:compare).with(anything, previous_deploy.reference, "commita").returns simple_response
      emails.must_equal ["static@example.com", "pete@example.com"]
    end

    it "is empty when deploy was a success" do
      deploy.job.success!
      emails.must_equal nil
    end

    it "is empty when last deploy was also a failure" do
      previous_deploy.job.fail!
      emails.must_equal nil
    end

    it "is empty when user was human" do
      user.update_attribute(:integration, false)
      emails.must_equal nil
    end

    it "includes committers when there is no previous deploy" do
      previous_deploy.delete
      emails.must_equal ["static@example.com"]
    end

    it "does not include commiiters if the author did not have a email" do
      GITHUB.expects(:compare).returns Hashie::Mash.new(commits: [{commit: {author: {}}}])
      emails.must_equal ["static@example.com"]
    end

    it "does not include commiiters when email_committers_on_automated_deploy_failure? if off" do
      subject.update_column(:email_committers_on_automated_deploy_failure, false)
      emails.must_equal ["static@example.com"]
    end

    it "does not have static when static is empty" do
      subject.update_column(:static_emails_on_automated_deploy_failure, "")
      GITHUB.expects(:compare).returns simple_response
      emails.must_equal ["pete@example.com"]
    end
  end

  describe ".build_clone" do
    before do
      subject.notify_email_address = "test@test.ttt"
      subject.flowdock_flows = [FlowdockFlow.new(name: "test", token: "abcxyz", stage_id: subject.id)]
      subject.save

      @clone = Stage.build_clone(subject)
    end

    it "returns an unsaved copy of the given stage with exactly the same everything except id" do
      @clone.attributes.except("id").must_equal subject.attributes.except("id")
      @clone.id.wont_equal subject.id
    end
  end

  describe '#production?' do
    let(:stage) { stages(:test_production) }
    before { DeployGroup.stubs(enabled?: true) }

    it 'is true for stage with production deploy_group' do
      stage.update!(production: false)
      stage.production?.must_equal true
    end

    it 'is false for stage with non-production deploy_group' do
      stage = stages(:test_staging)
      stage.production?.must_equal false
    end

    it 'false for stage with no deploy_group' do
      stage.update!(production: false)
      stage.deploy_groups = []
      stage.production?.must_equal false
    end

    it 'fallbacks to production field when deploy groups was enabled without selecting deploy groups' do
      stage.deploy_groups = []
      stage.update!(production: true)
      stage.production?.must_equal true
      stage.update!(production: false)
      stage.production?.must_equal false
    end

    it 'fallbacks to production field when deploy groups was disabled' do
      DeployGroup.stubs(enabled?: false)
      stage.update!(production: true)
      stage.production?.must_equal true
      stage.update!(production: false)
      stage.production?.must_equal false
    end
  end

  describe "#deploy_requires_approval?" do
    before do
      BuddyCheck.stubs(enabled?: true)
      stage.production = true
    end

    after do
      BuddyCheck.unstub(:enabled?)
    end

    it "requires approval with buddy-check + deploying + production" do
      assert stage.deploy_requires_approval?
    end

    it "does not require approval when buddy check is disabled" do
      BuddyCheck.stubs(enabled?: false)
      refute stage.deploy_requires_approval?
    end

    it "does not require approval when not in production" do
      stage.production = false
      refute stage.deploy_requires_approval?
    end

    it "does not require approval when not deploying code" do
      stage.no_code_deployed = true
      refute stage.deploy_requires_approval?
    end
  end

  describe '#deploy_group_names' do
    let(:stage) { stages(:test_production) }

    it 'returns array when DeployGroup enabled' do
      DeployGroup.stubs(enabled?: true)
      stage.deploy_group_names.must_equal ['Pod1', 'Pod2']
    end

    it 'returns empty array when DeployGroup disabled' do
      DeployGroup.stubs(enabled?: false)
      stage.deploy_group_names.must_equal []
    end
  end

  describe '#save' do
    it 'touches the stage and project when only changing deploy_groups for cache invalidation' do
      stage_updated_at = stage.updated_at
      project_updated_at = stage.project.updated_at
      stage.deploy_groups << deploy_groups(:pod1)
      stage.save
      stage_updated_at.wont_equal stage.updated_at
      project_updated_at.wont_equal stage.project.updated_at
    end
  end

  describe "#ensure_ordering" do
    it "puts new stages to the back" do
      new = stage.project.stages.create! name: 'Newish'
      new.order.must_equal 1
    end
  end

  describe "#destroy" do
    it "soft deletes all it's StageCommand" do
      assert_difference "StageCommand.count", -1 do
        stage.soft_delete!
      end

      assert_difference "StageCommand.count", +1 do
        stage.soft_undelete!
      end
    end
  end

  describe "#command_updated_at" do
    let(:t) { 3.seconds.from_now }

    it "is nil for new" do
      Stage.new.command_updated_at.must_equal nil
    end

    it "ignores updated_at since that is changed on every deploy" do
      stage.command_associations.clear
      stage.command_updated_at.must_equal nil
    end

    it "is updated when command content changed" do
      stage.commands.first.update_column(:updated_at, t)
      stage.command_updated_at.to_i.must_equal t.to_i
    end

    it "is updated when a new command was added" do
      stage.command_associations.first.update_column(:updated_at, t)
      stage.command_updated_at.to_i.must_equal t.to_i
    end
  end

  describe "versioning" do
    around { |t| PaperTrail.with_logging(&t) }

    it "tracks important changes" do
      stage.update_attribute(:name, "Foo")
      stage.versions.size.must_equal 1
    end

    it "ignores unimportant changes" do
      stage.update_attributes(order: 5, updated_at: 1.second.from_now)
      stage.versions.size.must_equal 0
    end

    it "records script" do
      stage.record_script_change
      YAML.load(stage.versions.first.object)['script'].must_equal stage.script
    end

    it "can restore ... but loses script" do
      old_name = stage.name
      stage.record_script_change
      stage.update_column(:name, "NEW-NAME")
      stage.commands.first.update_column(:command, 'NEW')
      stage.versions.last.reify.save!
      stage.reload
      stage.name.must_equal old_name
      stage.script.must_equal 'NEW'
    end

    it "does not trigger multiple times when destroying" do
      stage.destroy
      stage.versions.size.must_equal 1
    end
  end

  describe "#destroy_deploy_groups_stages" do
    it 'deletes deploy_groups_stages on destroy' do
      assert_difference 'DeployGroupsStage.count', -1 do
        stage.destroy!
      end
    end
  end
end
