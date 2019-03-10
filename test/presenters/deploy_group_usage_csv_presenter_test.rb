# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployGroupUsageCsvPresenter do
  describe ".to_csv" do
    it "generates csv" do
      expected_csv_rows = 1
      Project.all.each do |project|
        if project.stages.empty?
          expected_csv_rows += 1
        else
          project.stages.each do |stage|
            expected_csv_rows += stage.deploy_groups.count
          end
        end
      end
      DeployGroupUsageCsvPresenter.to_csv.split("\n").size.must_equal expected_csv_rows
    end
  end

  describe ".csv_header" do
    it "returns the list of column headers" do
      DeployGroupUsageCsvPresenter.send(:csv_header).must_equal(
        [
          "project_name",
          "stage_name",
          "deploy_group_name",
          "deploy_group_environment_id",
          "deploy_group_environment_name",
          "deploy_group_env_value",
          "deploy_group_permalink"
        ]
      )
    end
  end

  describe ".csv_line" do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }
    let(:deploy_group) { deploy_groups(:pod1) }

    it "returns a project line when only a project is available" do
      DeployGroupUsageCsvPresenter.send(:csv_line, project).must_equal(
        [project.name]
      )
    end

    it "returns a project line when a project and a stage is available but no deploy_group" do
      DeployGroupUsageCsvPresenter.send(:csv_line, project, stage).must_equal(
        [project.name]
      )
    end

    it "returns a project line when a project, stage, and deploy_group are available" do
      DeployGroupUsageCsvPresenter.send(:csv_line, project, stage, deploy_group).must_equal(
        [
          project.name,
          stage.name,
          deploy_group.name,
          deploy_group.environment_id,
          deploy_group.environment.name,
          deploy_group.env_value,
          deploy_group.permalink
        ]
      )
    end
  end
end
