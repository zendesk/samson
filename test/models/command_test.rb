# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2

describe Command do
  describe '.for_object' do
    let(:stage) { stages(:test_staging) }

    it "shows global for new stage" do
      Command.for_object(Stage.new).must_equal Command.global
    end

    it "shows global for new stage with new project" do
      Command.for_object(Stage.new(project: Project.new)).must_equal Command.global
    end

    it "sorts own commands in front" do
      stage.commands.size.must_be :>=, 1
      Command.for_object(stage).must_equal(
        stage.commands + (Command.global - stage.commands)
      )
    end

    it "sorts highly used commands to the front" do
      command = Command.create!(command: 'new')
      (Stage.all - [stage]).each do |stage|
        StageCommand.create!(stage: stage, command: command)
      end

      Command.for_object(stage).must_equal(
        stage.commands + [command] + (Command.global - stage.commands - [command])
      )
    end
  end

  describe "#trigger_stage_change" do
    let(:command) { commands(:echo) }

    with_paper_trail

    it "triggers a version when command changes" do
      command.update_attribute(:command, 'new')
      command.reload.stages.first.versions.size.must_equal 1
    end

    it "does not trigger when command does not change" do
      command.update_attribute(:project, nil)
      command.reload.stages.first.versions.size.must_equal 0
    end
  end
end
