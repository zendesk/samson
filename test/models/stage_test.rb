require_relative '../test_helper'

describe Stage do
  describe '#command' do
    subject { stages(:test_staging) }

    describe 'adding + sorting a command' do
      before do
        command = Command.create!(
          :name => 'test',
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
    before do
      Command.create!(
        :name => 'test',
        :command => 'test',
        :user => users(:admin)
      )
    end

    it 'includes all commands, sorted' do
      subject.all_commands.must_equal(subject.commands.push(Command.last))
    end
  end
end
