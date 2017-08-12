# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  subject { stages(:test_staging) }
  let(:stage) { subject }

  describe "validations" do
    it "is valid" do
      assert_valid stage
    end

    it "is valid with 1 email" do
      stage.notify_email_address = 'foo@bar.com'
      assert_valid stage
    end

    it "is invalid with email that contains spaces" do
      stage.notify_email_address = 'fo o@bar.com'
      refute_valid stage
    end

    it "is valid with trailing semicolon email" do
      stage.notify_email_address = 'foo@bar.com; '
      assert_valid stage
    end

    it "is invalid with weird emails" do
      stage.notify_email_address = 'sdfsfdfsd'
      refute_valid stage
    end

    it "is invalid with valid followed by invalid email" do
      stage.notify_email_address = 'foo@bar;sfdsdf;'
      refute_valid stage
    end

    it "is invalid with invalid followed by valid email" do
      stage.notify_email_address = 'sfdsdf;foo@bar'
      refute_valid stage
    end

    it "is valid with multiple valid emails" do
      stage.notify_email_address = 'foo@bar;bar@foo'
      assert_valid stage
    end
  end

  describe ".where_reference_being_deployed" do
    it "returns stages where the reference is currently being deployed" do
      project = projects(:test)
      stage = stages(:test_staging)
      author = users(:deployer)

      job = project.jobs.create!(user: author, commit: "a", command: "yes", status: "running")
      stage.deploys.create!(reference: "xyz", job: job, project: project)

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
      stage3.soft_delete!
      stage1.update! next_stage_ids: [stage3.id]

      Stage.reset_order [stage2.id, stage1.id]

      stage1.reload.order.must_equal 1
      stage2.reload.order.must_equal 0
    end
  end

  describe '#last_deploy' do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }

    it 'caches nil' do
      stage
      ActiveRecord::Relation.any_instance.expects(:first).returns nil
      stage.last_deploy.must_be_nil
      ActiveRecord::Relation.any_instance.expects(:first).never
      stage.last_deploy.must_be_nil
    end

    it 'returns the last deploy for the stage' do
      job = project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'succeeded')
      stage.deploys.create!(reference: 'master', job: job, project: project)
      job = project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'failed')
      deploy = stage.deploys.create!(reference: 'master', job: job, project: project)
      assert_equal deploy, stage.last_deploy
    end
  end

  describe '#last_successful_deploy' do
    let(:project) { projects(:test) }

    it 'caches nil' do
      subject
      ActiveRecord::Relation.any_instance.expects(:first).returns nil
      stage.last_successful_deploy.must_be_nil
      ActiveRecord::Relation.any_instance.expects(:first).never
      stage.last_successful_deploy.must_be_nil
    end

    it 'returns the last successful deploy for the stage' do
      successful_job = project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'succeeded')
      stage.deploys.create!(reference: 'master', job: successful_job, project: project)
      project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'failed')
      deploy = stage.deploys.create!(reference: 'master', job: successful_job, project: project)
      assert_equal deploy, stage.last_successful_deploy
    end
  end

  describe "#current_release?" do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }
    let(:author) { users(:deployer) }
    let(:job) { project.jobs.create!(user: author, commit: "x", command: "echo", status: "succeeded") }
    let(:releases) { Array.new(3).map { project.releases.create!(author: author, commit: "a" * 40) } }

    before do
      GitRepository.any_instance.stubs(:fuzzy_tag_from_ref).returns(nil)
      stage.deploys.create!(reference: "v124", job: job, project: project)
      stage.deploys.create!(reference: "v125", job: job, project: project)
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
      subject.current_deploy.must_be_nil
    end

    it 'caches nil' do
      subject
      ActiveRecord::Relation.any_instance.expects(:first).returns nil
      subject.current_deploy.must_be_nil
      ActiveRecord::Relation.any_instance.expects(:first).never
      subject.current_deploy.must_be_nil
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
      stage = Stage.new(notify_email_address: "a@foo.com;b@foo.com ; c@foo.com; ")
      stage.notify_email_addresses.must_equal ["a@foo.com", "b@foo.com", "c@foo.com"]
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
      GITHUB.expects(:compare).with(anything, previous_deploy.job.commit, "commita").returns simple_response
      emails.must_equal ["static@example.com", "pete@example.com"]
    end

    it "is empty when deploy was a success" do
      deploy.job.success!
      emails.must_be_nil
    end

    it "is empty when last deploy was also a failure" do
      previous_deploy.job.fail!
      emails.must_be_nil
    end

    it "is empty when last deploy was also a error" do
      previous_deploy.job.error!
      emails.must_be_nil
    end

    it "is empty when user was human" do
      user.update_attribute(:integration, false)
      emails.must_be_nil
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
      @clone.attributes.except("id").except("template_stage_id").
          must_equal subject.attributes.except("id").except("template_stage_id")
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
      stage.production = true
      stage.production?.must_equal true
      stage.production = false
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

    it "requires approval with buddy-check + deploying + production" do
      assert stage.deploy_requires_approval?
    end

    it "does not require approval when buddy check is disabled" do
      BuddyCheck.unstub(:enabled?)
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
      stage.update_column(:updated_at, 1.minutes.ago)
      stage.project.update_column(:updated_at, 1.minutes.ago)

      stage.deploy_groups << deploy_groups(:pod1)
      stage.save

      stage.updated_at.must_be :>, 2.seconds.ago
      stage.project.updated_at.must_be :>, 2.seconds.ago
    end
  end

  describe "#ensure_ordering" do
    it "puts new stages to the back" do
      new = stage.project.stages.create! name: 'Newish'
      new.order.must_equal 3
    end
  end

  describe "#destroy" do
    it "soft deletes all it's StageCommand" do
      Stage.with_deleted do
        assert_difference "StageCommand.count", -1 do
          stage.soft_delete!
        end

        assert_difference "StageCommand.count", +1 do
          stage.soft_undelete!
        end
      end
    end

    it "removes the stage from the pipeline of other stages" do
      other_stage = Stage.create!(project: stage.project, name: 'stage1', next_stage_ids: [stage.id])
      assert other_stage.next_stage_ids.include?(stage.id)
      stage.soft_delete!
      refute other_stage.reload.next_stage_ids.include?(stage.id)
    end
  end

  describe '#script' do
    it 'joins all commands based on position' do
      command = Command.create!(command: 'test')
      stage.command_ids = [command.id, commands(:echo).id]
      stage.save!
      stage.reload
      stage.script.must_equal "test\n#{commands(:echo).command}"
    end

    it 'is empty without commands' do
      stage.command_ids = []
      stage.script.must_equal ""
    end
  end

  describe "#command=" do
    it 'add new command to the end' do
      stage.update_attributes!(
        command: 'test',
        command_ids: [commands(:echo).id]
      )
      stage.reload
      stage.script.must_equal "#{commands(:echo).command}\ntest"
    end

    it "can add a single command" do
      stage.send(:stage_commands).delete_all
      stage.update_attributes!(command: 'test')
      stage.script.must_equal "test"
    end
  end

  describe '#command_ids=' do
    let!(:sample_commands) do
      ['foo', 'bar', 'baz'].map { |c| Command.create!(command: c) }
    end

    before do
      StageCommand.delete_all
      stage.command_ids = sample_commands.map(&:id)
      stage.script.must_equal "foo\nbar\nbaz"
    end

    it "can reorder" do
      stage.command_ids = sample_commands.map(&:id).reverse
      stage.save!
      stage.script.must_equal "baz\nbar\nfoo"
      stage.reload
      stage.script.must_equal "baz\nbar\nfoo"
      stage.send(:stage_commands).sort_by(&:id).map(&:position).must_equal [2, 1, 0]
    end

    it "ignores blanks" do
      stage.command_ids = ['', nil, ' '] + sample_commands.map(&:id).reverse
      stage.save!
      stage.script.must_equal "baz\nbar\nfoo"
      stage.reload
      stage.script.must_equal "baz\nbar\nfoo"
      stage.send(:stage_commands).sort_by(&:id).map(&:position).must_equal [2, 1, 0]
    end

    it "can add new commands" do
      stage.command_ids = ([commands(:echo)] + sample_commands).map(&:id)
      stage.save!
      stage.script.must_equal "echo hello\nfoo\nbar\nbaz"
      stage.reload
      stage.script.must_equal "echo hello\nfoo\nbar\nbaz"
      stage.send(:stage_commands).sort_by(&:id).map(&:position).must_equal [1, 2, 3, 0] # kept the old and added one new
    end
  end

  describe "auditing" do
    it "tracks important changes" do
      stage.update_attributes!(name: "Foo")
      stage.audits.size.must_equal 1
      stage.audits.first.audited_changes.must_equal "name" => ["Staging", "Foo"]
    end

    it "ignores unimportant changes" do
      stage.update_attributes(order: 5, updated_at: 1.second.from_now)
      stage.audits.size.must_equal 0
    end

    it "tracks command addition" do
      stage.update_attributes!(command: "Foo")
      stage.audits.size.must_equal 1
      stage.audits.first.audited_changes.must_equal "script" => ["echo hello", "echo hello\nFoo"]
    end

    it "tracks selecting an existing command" do
      old = stage.command_ids
      new = old + [commands(:global).id]
      stage.update_attributes!(command_ids: new)
      stage.audits.size.must_equal 1
      stage.audits.first.audited_changes.must_equal "script" => ["echo hello", "echo hello\necho global"]
    end

    it "tracks command removal" do
      stage.update_attributes!(command_ids: [])
      stage.audits.size.must_equal 1
      stage.audits.first.audited_changes.must_equal "script" => ["echo hello", ""]
    end

    it "does not track when command does not change" do
      stage.update_attributes!(command_ids: stage.command_ids.map(&:to_s), command: "")
      stage.audits.size.must_equal 0
    end

    it "tracks simulatanous command and command_ids change" do
      stage.update_attributes!(name: 'Foobar', command_ids: Command.pluck(:id), command: "foo")
      stage.audits.size.must_equal 1
      stage.audits.first.audited_changes.must_equal(
        "name" => ["Staging", "Foobar"],
        "script" => ["echo hello", "echo hello\necho global\nfoo"]
      )
    end

    it "tracks command_ids reorder" do
      stage.send(:stage_commands).create!(command: commands(:global), position: 1)
      stage.update_attributes!(command_ids: stage.command_ids.reverse)
      stage.audits.size.must_equal 1
      stage.audits.first.audited_changes.must_equal(
        "script" => ["echo hello\necho global", "echo global\necho hello"]
      )
    end

    it "tracks external command change" do
      stage.send(:stage_commands).first.command.update_attributes!(command: "NEW")
      stage.audits.first.audited_changes.must_equal "script" => ["echo hello", "NEW"]
    end

    it "does not trigger multiple times when destroying" do
      stage.destroy!
      stage.audits.size.must_equal 1
    end

    it "does not trigger multiple times when creating" do
      stage = Stage.create!(name: 'Foobar', project: projects(:test), command_ids: Command.pluck(:id), command: "foo")
      stage.audits.size.must_equal 1
    end
  end

  describe "#destroy_deploy_groups_stages" do
    it 'deletes deploy_groups_stages on destroy' do
      assert_difference 'DeployGroupsStage.count', -1 do
        stage.destroy!
      end
    end
  end

  describe "#influencing_stage_ids" do
    let(:other) { stages(:test_production) }

    it "finds self when there are none" do
      stage.influencing_stage_ids.must_equal [stage.id]
    end

    describe "with other stage" do
      before { DeployGroupsStage.create!(stage: other, deploy_group: stage.deploy_groups.first) }

      it "finds other stages that go to the same deploy groups" do
        stage.influencing_stage_ids.sort.must_equal [stage.id, other.id].sort
      end

      it "does not find stages in other projects" do
        other.update_column(:project_id, 123)
        stage.influencing_stage_ids.sort.must_equal [stage.id]
      end

      it "does not list stages that prepare the deploy to avoid false-positives" do
        other.update_column(:no_code_deployed, true)
        stage.influencing_stage_ids.sort.must_equal [stage.id]
      end
    end
  end

  describe '#build_new_project_command' do
    it "adds new command to the end of commands" do
      stage.command = "yep"
      stage.save!
      stage.script.must_equal "echo hello\nyep"
      Command.last.project_id.must_equal stage.project_id
    end

    it "does not add an empty command" do
      stage.command = ""
      stage.save!
      stage.script.must_equal "echo hello"
    end
  end

  describe "template linking" do
    describe "with no clones" do
      it "has no parent" do
        assert_nil subject.template_stage
      end

      it "has no clones" do
        assert_empty subject.clones
      end
    end

    describe "with one clone" do
      before do
        @clone = Stage.build_clone(subject)
        @clone.name = "foo1"
        @clone.save!
        @clone.reload
      end

      it "has one parent" do
        assert_equal subject, @clone.template_stage
      end

      it "has one clone" do
        assert_equal [@clone], subject.clones
      end
    end

    describe "with many clones" do
      before do
        @clone1 = Stage.build_clone(subject)
        @clone1.name = "foo1"
        @clone1.save!
        @clone1.reload

        @clone2 = Stage.build_clone(subject)
        @clone2.name = "foo2"
        @clone2.save!
        @clone2.reload

        @clones = [@clone1, @clone2]
      end

      it "has one parent" do
        @clones.each do |c|
          assert_equal subject, c.template_stage
        end
      end

      it "has multiple clones" do
        assert_equal @clones, subject.clones
      end
    end
  end

  describe "#validate_deploy_group_selected" do
    it "is valid without deploy groups" do
      stage.deploy_groups.clear
      assert_valid stage
    end

    describe "with deploy group feature" do
      before { DeployGroup.stubs(enabled?: true) }

      it "is valid with deploy groups" do
        assert_valid stage
      end

      describe "without deploy groups" do
        before { stage.deploy_groups.clear }

        it "is not valid" do
          refute_valid stage
        end

        it "is valid when being the automated stage" do
          stage.name = Stage::AUTOMATED_NAME
          assert_valid stage
        end
      end
    end
  end

  describe "#direct" do
    before do
      stage.confirm = false
      stage.no_reference_selection = true
    end

    it "is direct" do
      assert stage.direct?
    end

    it "is not direct when confirmation is required" do
      stage.confirm = true
      refute stage.direct?
    end

    it "is not direct when reference selection is required" do
      stage.no_reference_selection = false
      refute stage.direct?
    end

    # this could be loosened, but then we have to make sure it goes to pending and not
    # into a running deploy
    it "is not direct when approval is required" do
      stage.stubs(deploy_requires_approval?: true)
      refute stage.direct?
    end
  end
end
