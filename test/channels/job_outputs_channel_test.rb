# frozen_string_literal: true
require_relative '../test_helper'

# SingleCov.covered!

describe JobOutputsChannel do
  describe JobOutputsChannel::EventBuilder do
    let(:job) { jobs(:succeeded_test) }
    let(:builder) { JobOutputsChannel::EventBuilder.new(job) }

    it "renders a header" do
      builder.payload(:started, nil)
    end
  end
end
