require_relative '../test_helper'

describe Stage do
  subject { stages(:test_staging) }

  describe '#command' do
    describe 'adding a built command' do
      before do
        subject.stage_commands.build(command:
          Command.new(:command => 'test', :user => users(:admin))
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
        command = Command.create!(
          :command => 'test',
          :user => users(:admin)
        )

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

  describe '#all_commands' do
    describe 'with commands' do
      before do
        Command.create!(
          :command => 'test',
          :user => users(:admin)
        )
      end

      it 'includes all commands, sorted' do
        subject.all_commands.must_equal(subject.commands.push(Command.last))
      end
    end

    describe 'no commands' do
      subject { Stage.new }

      it 'includes all commands' do
        subject.all_commands.must_equal(Command.all)
      end
    end
  end
end
