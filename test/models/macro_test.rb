require_relative '../test_helper'

SingleCov.covered!

describe Macro do
  subject { macros(:test) }

  describe '#command' do
    it 'joins all commands based on position' do
      command = Command.create!(command: 'test')

      subject.command_ids = [command.id, commands(:echo).id]
      subject.save!
      subject.reload

      subject.script.must_equal("test\n#{commands(:echo).command}")
    end

    it "is empty without commands" do
      subject.command_associations.clear
      subject.script.must_equal('')
    end
  end

  describe "#command=" do
    it "adds a new comand" do
      subject.command = "HELLOOOO"
      subject.save!
      subject.reload.commands.map(&:command).must_equal ["echo hello", "HELLOOOO"]
    end

    it "does not add a empty command" do
      subject.command = "   "
      subject.save!
      subject.reload.commands.map(&:command).must_equal ["echo hello"]
    end
  end
end
