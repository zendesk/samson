# frozen_string_literal: true

require_relative '../../test_helper'
require 'irb'

SingleCov.covered!

describe Samson::ReadonlyDb do
  after { Samson::ReadonlyDb.disable }

  describe "#enable" do
    it "allows write queries when disabled" do
      assert_difference("User.count", +1) { User.create!(name: "Foo") }
    end

    it "blocks write queries when enabled" do
      Samson::ReadonlyDb.enable
      assert_difference "User.count", 0 do
        assert_raises(ActiveRecord::ReadOnlyRecord) { User.create!(name: "Foo") }
      end
    end

    it "allows read queries when enable" do
      Samson::ReadonlyDb.enable
      User.first!
    end

    it "does not add 2 hooks when enabling twice" do
      ActiveSupport::Notifications.expects(:subscribe).times(1).returns(1)
      2.times { Samson::ReadonlyDb.enable }
    end

    it "changes the prompt by in-place modifying" do
      i = +"a(b)"
      n = +"b(c)"
      IRB.conf[:PROMPT] = {RAILS_ENV: {PROMPT_I: i, PROMPT_N: n}}

      Samson::ReadonlyDb.enable
      i.must_equal "a(readonly b)"
      n.must_equal "b(readonly c)"

      Samson::ReadonlyDb.disable
      i.must_equal "a(b)"
      n.must_equal "b(c)"
    ensure
      IRB.conf[:PROMPT].clear
    end
  end

  describe "#disable" do
    before { Samson::ReadonlyDb.enable }

    it "allows write queries when disabled" do
      Samson::ReadonlyDb.disable
      assert_difference("User.count", +1) { User.create!(name: "Foo") }
    end

    it "does not fail when disabling twice" do
      2.times { Samson::ReadonlyDb.disable }
    end
  end
end
