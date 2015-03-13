require_relative '../test_helper'

describe Macro do
  subject { macros(:test) }

  describe '#command' do
    describe 'adding + sorting a command' do
      before do
        command = Command.create!(command: 'test')

        subject.command_ids = [command.id, commands(:echo).id]
        subject.save!
        subject.reload
      end

      it 'joins all commands based on position' do
        subject.command.must_equal("test\n#{commands(:echo).command}\nseq 1 5")
      end
    end

    describe 'no commands' do
      before { subject.commands.clear }

      it 'is only the macro command' do
        subject.command.must_equal('seq 1 5')
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
      subject { project.macros.build }

      it 'includes all commands' do
        subject.all_commands.must_equal(Command.for_project(project))
      end
    end
  end
end
