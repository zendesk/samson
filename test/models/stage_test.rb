require_relative '../test_helper'

describe Stage do
  subject { stages(:test_staging) }

  describe '#command' do
    describe 'adding a built command' do
      before do
        subject.stage_commands.build(command:
          Command.new(:command => 'test')
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
end
