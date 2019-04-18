# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::BuddyCheck do
  describe ".enabled?" do
    it "is enabled when set" do
      with_env BUDDY_CHECK_FEATURE: "1" do
        assert Samson::BuddyCheck.enabled?
      end
    end

    it "is disabled when false" do
      with_env BUDDY_CHECK_FEATURE: "false" do
        refute Samson::BuddyCheck.enabled?
      end
    end

    it "is disabled when not set" do
      refute Samson::BuddyCheck.enabled?
    end
  end

  describe ".grace_period" do
    it "is 4 hours by default" do
      Samson::BuddyCheck.grace_period.must_equal 4.hours
    end

    it "can be changed" do
      with_env BUDDY_CHECK_GRACE_PERIOD: '2' do
        Samson::BuddyCheck.grace_period.must_equal 2.hours
      end
    end

    it "ignores empty" do
      with_env BUDDY_CHECK_GRACE_PERIOD: '' do
        Samson::BuddyCheck.grace_period.must_equal 4.hours
      end
    end

    it "fails on bad" do
      with_env BUDDY_CHECK_GRACE_PERIOD: 'foo' do
        assert_raises(ArgumentError) { Samson::BuddyCheck.grace_period }
      end
    end
  end

  describe ".time_limit" do
    it "defaults to 20 minutes" do
      Samson::BuddyCheck.time_limit.must_equal 20.minutes
    end

    it "can read BUDDY_CHECK_TIME_LIMIT" do
      with_env BUDDY_CHECK_TIME_LIMIT: "10" do
        Samson::BuddyCheck.time_limit.must_equal 10.minutes
      end
    end

    it "can read deprecated DEPLOY_MAX_MINUTES_PENDING" do
      with_env DEPLOY_MAX_MINUTES_PENDING: "10" do
        Samson::BuddyCheck.time_limit.must_equal 10.minutes
      end
    end

    it "fails nicely with invalid number" do
      with_env DEPLOY_MAX_MINUTES_PENDING: "foo" do
        assert_raises(ArgumentError) { Samson::BuddyCheck.time_limit }
      end
    end
  end

  describe ".bypass_email_addresses" do
    it "is empty by default" do
      Samson::BuddyCheck.bypass_email_addresses.must_equal []
    end

    it "reads BYPASS_EMAIL" do
      with_env BYPASS_EMAIL: "a@b.com,b@c.com" do
        Samson::BuddyCheck.bypass_email_addresses.must_equal ["a@b.com", "b@c.com"]
      end
    end

    it "reads BYPASS_JIRA_EMAIL" do
      with_env BYPASS_JIRA_EMAIL: "a@b.com" do
        Rails.logger.expects(:warn).with("BYPASS_JIRA_EMAIL is deprecated")
        Samson::BuddyCheck.bypass_email_addresses.must_equal ["a@b.com"]
      end
    end
  end
end
