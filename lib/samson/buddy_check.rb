# frozen_string_literal: true
module Samson
  module BuddyCheck
    class << self
      def enabled?
        Samson::EnvCheck.set?("BUDDY_CHECK_FEATURE")
      end

      def bypass_enabled?
        !Samson::EnvCheck.set?("DISABLE_BUDDY_BYPASS_FEATURE")
      end

      # how long can the same commit be deployed ?
      def grace_period
        Integer(ENV["BUDDY_CHECK_GRACE_PERIOD"].presence || "4").hours
      end

      def time_limit
        Integer(ENV["BUDDY_CHECK_TIME_LIMIT"] || ENV["DEPLOY_MAX_MINUTES_PENDING"] || "20").minutes
      end

      def bypass_email_addresses
        emails = ENV["BYPASS_EMAIL"].to_s.split(",")
        if jira = ENV["BYPASS_JIRA_EMAIL"]
          Rails.logger.warn "BYPASS_JIRA_EMAIL is deprecated"
          emails << jira
        end
        emails
      end
    end
  end
end
