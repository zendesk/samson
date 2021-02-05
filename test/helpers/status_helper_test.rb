# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe StatusHelper do
  include ERB::Util
  include DateTimeHelper

  let(:current_user) { users(:viewer) }

  describe "#status_panel" do
    let(:deploy) { deploys(:succeeded_production_test) }
    let(:job) { jobs(:running_test) }
    it "accepts a deploy" do
      refute_nil status_panel(deploy)
    end

    it "accepts a job" do
      refute_nil status_panel(job)
    end

    it 'shows duration text for deploys' do
      deploy.stage.update_column(:average_deploy_time, 3)
      deploy.expects(:active?).returns(true)

      status_panel(deploy).must_include 'Expected duration: 00:00:03.'
    end

    it 'does not show duration text for jobs' do
      job.expects(:active?).returns(true)

      status_panel(job).wont_include 'Expected duration: 00:00:03.'
    end
  end

  describe '#status_badge' do
    it 'renders' do
      status_badge("succeeded").must_include "Succeeded"
    end
  end

  describe "#status_label" do
    it "renders" do
      status_label("succeeded").must_equal "label-success"
    end
  end

  describe "#duration_text" do
    it "shows duration" do
      duration_text(5 * 60 * 60 + 59 * 60 + 4).must_equal "05:59:04"
    end

    it "shows nothing if duration is nil" do
      duration_text(nil).must_equal ''
    end
  end
end
