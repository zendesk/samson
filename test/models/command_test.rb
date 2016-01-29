require_relative '../test_helper'

describe Command do
  describe '.for_object' do
    it "shows global for new stage" do
      Command.for_object(Stage.new).must_equal Command.global
    end

    it "shows global for new stage with new project" do
      Command.for_object(Stage.new(project: Project.new)).must_equal Command.global
    end

    it "sorts own commands in front" do
      stage = stages(:test_staging)
      Command.for_object(stage).must_equal(
        stage.commands + (Command.global - stage.commands)
      )
    end
  end
end
