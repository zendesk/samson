require_relative '../test_helper'

describe Stage do
  describe '#command' do
    subject { stages(:test_staging) }

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
end
