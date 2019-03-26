# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployMetricsCsvPresenter do
  describe ".to_csv" do
    it "generates csv" do
      # starts with 1, for csv header
      expected_csv_rows = 1
      production_stages = Stage.select(&:production?)
      deploys = Deploy.succeeded.where(stage: production_stages).includes(:job, stage: :project)
      expected_csv_rows += deploys.size
      DeployMetricsCsvPresenter.to_csv.count.must_equal expected_csv_rows
    end
  end

  describe ".csv_header" do
    it "returns the list of column headers" do
      DeployMetricsCsvPresenter.send(:csv_header).must_equal(
        [
          "Deploy Number",
          "Project Name",
          "Deploy Commit",
          "Deploy Status",
          "Stage Name",
          "PR - Production Cycle Time",
          "Staging - Production Cycle Time"
        ]
      )
    end
  end

  describe ".csv_line" do
    let(:deploy) { deploys(:succeeded_production_test) }

    it "returns the list of csv lines" do
      DeployMetricsCsvPresenter.send(:csv_line, deploy).must_equal(
        [
          deploy.id,
          deploy.stage.project.permalink,
          deploy.commit,
          deploy.job.status,
          deploy.stage.name,
          deploy.cycle_time[:pr_production],
          deploy.cycle_time[:staging_production]
        ]
      )
    end
  end
end
