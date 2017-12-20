# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe StatusHelper do
  include ERB::Util
  include DateTimeHelper

  let(:current_user) { users(:viewer) }

  describe "#status_panel" do
    it "accepts a deploy" do
      refute_nil status_panel(deploys(:succeeded_production_test))
    end

    it "accepts a job" do
      refute_nil status_panel(jobs(:running_test))
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
  end
end
