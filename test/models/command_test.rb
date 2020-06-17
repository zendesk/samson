# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe Command do
  let(:command) { commands(:echo) }

  describe '.for_stage' do
    let(:stage) { stages(:test_staging) }

    it "shows global for new stage" do
      Command.for_stage(Stage.new).must_equal Command.global
    end

    it "shows global for new stage with new project" do
      Command.for_stage(Stage.new(project: Project.new)).must_equal Command.global
    end

    it "sorts own commands in front" do
      stage.commands.size.must_be :>=, 1
      Command.for_stage(stage).must_equal(
        stage.commands + (Command.global - stage.commands)
      )
    end

    it "sorts highly used commands to the front" do
      command = Command.create!(command: 'new')
      (Stage.all - [stage]).each do |stage|
        StageCommand.create!(stage: stage, command: command)
      end

      Command.for_stage(stage).must_equal(
        stage.commands + [command] + (Command.global - stage.commands - [command])
      )
    end
  end

  describe "#global?" do
    it "is global when it does not belong to a project" do
      command.project = nil
      command.global?.must_equal true
    end

    it "is not global when it belongs to a project" do
      command.project = projects(:test)
      command.global?.must_equal false
    end
  end

  describe "#usages" do
    it "lists stages and projects" do
      projects(:test).update_column(:build_command_id, command.id)
      command.usages.map(&:class).uniq.sort_by(&:name).must_equal [Project, Stage]
    end
  end

  describe ".usage_ids" do
    it "returns all used commands" do
      extra_id = Command.create!(command: 'foo').id
      projects(:test).update_column(:build_command_id, extra_id)
      Command.usage_ids.uniq.sort.must_equal [extra_id, command.id].sort
    end

    it "does not include nils" do
      Command.usage_ids.wont_include nil
    end
  end

  describe ".cleanup_global" do
    let(:global) { commands(:global) }

    before do
      StageCommand.create! stage: stages(:test_staging), command: global
      StageCommand.create! stage: stages(:test_production), command: global
    end

    it "does nothing when all is good" do
      assert_difference("Command.count", 0) { Command.cleanup_global }
      refute global.reload.project
    end

    it "assigns global commands only used by a single stage" do
      StageCommand.last.destroy!
      assert_difference("Command.count", 0) { Command.cleanup_global }
      assert global.reload.project
    end

    it "assigns global commands only used by a single project" do
      global.stage_commands.destroy_all
      projects(:test).update_column(:build_command_id, global.id)
      assert_difference("Command.count", 0) { Command.cleanup_global }
      assert global.reload.project
    end

    it "deletes unused global commands with audit" do
      global.stage_commands.destroy_all
      assert_difference("Command.count", -1) { Command.cleanup_global }
      global.audits.size.must_equal 1
    end
  end

  describe "#usage_ids" do
    it "is empty for new" do
      Command.new.usage_ids.must_equal []
    end
  end

  describe "#ensure_unused" do
    it "does not destroy used" do
      refute command.destroy
      command.errors.full_messages.must_equal ['Can only delete when unused.']
    end

    it "destroys when unused" do
      command.stage_commands.delete_all
      assert command.destroy
      command.errors.full_messages.must_equal []
    end
  end
end
