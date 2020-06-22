# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe NullUser do
  describe "#name" do
    it "has no name when not found" do
      NullUser.new(11211212).name.must_equal 'Deleted User'
    end

    it "shows the name of a deleted user" do
      user = users(:viewer)
      user.soft_delete!(validate: false)
      NullUser.new(user.id).name.must_equal 'Viewer'
    end

    it "caches no user" do
      null = NullUser.new(11211212)

      User.expects(:find_by_sql).returns []
      null.name.must_equal 'Deleted User'
      User.expects(:find_by_sql).never
      null.name.must_equal 'Deleted User'
    end

    it "caches deleted user" do
      user = users(:viewer)
      user.soft_delete!(validate: false)
      null = NullUser.new(user.id)

      User.expects(:find_by_sql).returns [user]
      null.name.must_equal 'Viewer'

      User.expects(:find_by_sql).never
      null.name.must_equal 'Viewer'
    end
  end

  describe "email" do
    it "has a placeholder" do
      NullUser.new(1).email.must_equal 'deleted-user-1'
    end
  end

  describe "#attributes" do
    it "returns a limited list" do
      NullUser.new(11211212).attributes.must_equal("name" => "Deleted User")
    end
  end

  describe "#marked_for_destruction?" do
    it "is never marked for destruction" do
      refute NullUser.new(12).marked_for_destruction?
    end
  end
end
