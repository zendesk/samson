require_relative '../test_helper'

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
end
