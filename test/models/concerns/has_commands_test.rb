# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe HasCommands do
  let(:stage) { stages(:test_staging) }

  describe '#script' do
    describe 'adding a built command' do
      before do
        stage.command_associations.build(
          command: Command.new(command: 'test')
        )

        stage.command_ids = [commands(:echo).id]
        stage.save!
        stage.reload
      end

      it 'add new command to the end' do
        stage.script.must_equal("#{commands(:echo).command}\ntest")
      end
    end

    describe 'adding + sorting a command' do
      before do
        command = Command.create!(command: 'test')

        stage.command_ids = [command.id, commands(:echo).id]
        stage.save!
        stage.reload
      end

      it 'joins all commands based on position' do
        stage.script.must_equal("test\n#{commands(:echo).command}")
      end
    end

    describe 'no commands' do
      before { stage.commands.clear }

      it 'is empty' do
        stage.script.must_be_empty
      end
    end
  end

  describe '#command_ids=' do
    let!(:sample_commands) do
      ['foo', 'bar', 'baz'].map { |c| Command.create!(command: c) }
    end

    before do
      StageCommand.delete_all
      stage.commands = sample_commands
      stage.reload
    end

    it "can reorder" do
      stage.command_ids = sample_commands.map(&:id).reverse
      stage.save!
      stage.reload
      stage.script.must_equal "baz\nbar\nfoo"
      stage.command_associations.sort_by(&:id).map(&:position).must_equal [2, 1, 0]
    end

    it "ignores blanks" do
      stage.command_ids = ['', nil, ' '] + sample_commands.map(&:id).reverse
      stage.save!
      stage.reload
      stage.script.must_equal "baz\nbar\nfoo"
      stage.command_associations.sort_by(&:id).map(&:position).must_equal [2, 1, 0]
    end

    it "can add new commands" do
      stage.command_ids = ([commands(:echo)] + sample_commands).map(&:id)
      stage.save!
      stage.reload
      stage.script.must_equal "echo hello\nfoo\nbar\nbaz"
      stage.command_associations.sort_by(&:id).map(&:position).must_equal [1, 2, 3, 0]
    end
  end

  describe '#build_new_project_command' do
    it "adds new command to the end of commands" do
      stage.command = "yep"
      stage.save!
      stage.commands.map(&:command).must_equal ["echo hello", "yep"]
      Command.last.project_id.must_equal stage.project_id
    end

    it "does not add an empty command" do
      stage.command = ""
      stage.save!
      stage.commands.map(&:command).must_equal ["echo hello"]
    end
  end
end
