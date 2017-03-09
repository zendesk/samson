# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe HasRole do
  describe "#role" do
    it "finds the role" do
      User.new(role_id: Role::ADMIN.id).role.must_equal Role::ADMIN
    end

    it "returns viewer when nil" do
      User.new.role.must_equal Role::VIEWER
    end
  end

  describe "dynamic role method" do
    it "is true when role_id is greater than requested" do
      assert User.new(role_id: Role::SUPER_ADMIN.id).admin?
    end

    it "is true when role_id is equal" do
      assert User.new(role_id: Role::ADMIN.id).admin?
    end

    it "is false when role_id is lower than requested" do
      refute User.new(role_id: Role::VIEWER.id).admin?
    end
  end
end
