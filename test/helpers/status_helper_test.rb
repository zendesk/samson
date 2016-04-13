require_relative '../test_helper'

SingleCov.covered!

describe StatusHelper do
  include ERB::Util
  include DateTimeHelper

  describe "#status_panel" do
    it "accepts a deploy" do
      refute_nil status_panel(deploys(:succeeded_production_test))
    end

    it "accepts a job" do
      refute_nil status_panel(jobs(:running_test))
    end
  end

  describe "#status_label" do
    it "renders" do
      status_label("succeeded").must_equal "label-success"
    end
  end
end
