# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployGroupUsageCsvPresenter do
  describe ".csv_header" do
    it "returns the list of column headers" do
      DeployGroupUsageCsvPresenter.csv_header(project).must_equal(
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
    let(:deploy_group) do
      DeployGroup.create!(
        name: 'Pod 101',
        environment: env,
        env_value: 'test env value',
        permalink: 'test permalink value'
      )
    end

    it "returns a project line when only a project is available" do
      DeployGroupUsageCsvPresenter.csv_line(project).must_equal(
        [project.name]
      )
    end

    it "returns a project line when a project and a stage is available but no deploy_group" do
      DeployGroupUsageCsvPresenter.csv_line(project, stage).must_equal(
        [project.name]
      )
    end

    it "returns a project line when a project, stage, and eploy_group are available" do
      DeployGroupUsageCsvPresenter.csv_line(project, stage, deploy_group).must_equal(
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
