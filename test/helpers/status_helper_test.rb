# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe StatusHelper do
  include ERB::Util
  include DateTimeHelper

  let(:current_user) { users(:viewer) }

  describe "#status_panel" do
    let(:deploy) { deploys(:succeeded_production_test) }

    it "accepts a deploy" do
      assert status_panel(deploy)
    end

    it "renders a weird deploy without started_at" do
      deploy.job.created_at = nil
      assert status_panel(deploy)
    end

    it "renders a weird deploy without finished_at" do
      deploy.job.status = 'running'
      assert status_panel(deploy)
    end

    it "accepts a job" do
      assert status_panel(jobs(:running_test))
    end
  end

  describe "#status_label" do
    it "renders" do
      status_label("succeeded").must_equal "label-success"
    end
  end

  describe "#duration_text" do
    it "shows seconds when there is nothing" do
      duration_text(0).must_equal " 0 seconds"
    end

    it "shows seconds" do
      duration_text(12).must_equal " 12 seconds"
    end

    it "shows minutes and seconds" do
      duration_text(61).must_equal "1 minute 1 second"
    end

    it "shows only minutes when seconds are 0" do
      duration_text(60).must_equal "1 minute"
    end
  end
end
