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
        subject.macro_command.must_equal("test\n#{commands(:echo).command}\nseq 1 5")
      end
    end

    describe 'no commands' do
      before { subject.macro_commands.clear }

      it 'is only the macro command' do
        subject.macro_command.must_equal('seq 1 5')
      end
    end
  end
end
