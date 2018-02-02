# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Project do
  let(:project) { projects(:test) }

  describe "#validate_not_using_gcb_and_external" do
    it "is valid with just GCB" do
      project.build_with_gcb = true
      assert_valid project
    end

    it "is valid with just external" do
      project.docker_image_building_disabled = true
      assert_valid project
    end

    it "is not valid with GCB and external" do
      project.docker_image_building_disabled = true
      project.build_with_gcb = true
      refute_valid project
      project.errors.full_messages.must_equal(
        ["Build with gcb cannot be enabled when Docker images are built externally"]
      )
    end
  end
end
