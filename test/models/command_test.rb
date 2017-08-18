# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

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
  end

  describe "#destroy" do
    describe "with no usages" do
      before do
        StageCommand.delete_all
        assert_equal command.usages.count, 0
      end

      it "destroys successfully" do
        assert command.destroy
      end
    end

    describe "with usages" do
      before do
        assert_not_equal command.usages.count, 0
      end

      it "fails to destroy" do
        refute command.destroy
      end

      it "has an error message" do
        command.destroy
        assert_equal command.errors.full_messages, ['Can only delete unused commands.']
      end
    end
  end
end
