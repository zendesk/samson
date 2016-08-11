# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Role do
  describe "#display_name" do
    it "looks nice" do
      Role::ADMIN.display_name.must_equal "Admin"
    end
  end
end
