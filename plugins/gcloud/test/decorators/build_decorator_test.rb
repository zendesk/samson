# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Build do
  let(:build) { builds(:docker_build) }

  describe "#gcr_id" do
    it "is nil when not external" do
      build.gcr_id.must_be_nil
    end

    it "is set when on gcr" do
      id = "ee5316fa-5569-aaaa-bbbb-09e0e5b1319a"
      build.external_url = "https://console.cloud.google.com/gcr/builds/#{id}?project=foobar"
      build.gcr_id.must_equal id
    end

    it "is not set when not on gcr" do
      id = "ee5316fa-5569-aaaa-bbbb-09e0e5b1319a"
      build.external_url = "https://foo.com/bar/#{id}?project=foobar"
      build.gcr_id.must_be_nil
    end
  end
end
