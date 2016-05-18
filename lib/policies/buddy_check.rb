module BuddyCheck
  module_function

  def enabled?
    "1" == ENV["BUDDY_CHECK_FEATURE"]
  end

  def bypass_email_address
    ENV["BYPASS_EMAIL"]
  end

  # how long can the same commit be deployed ?
  def grace_period
    (ENV["BUDDY_CHECK_GRACE_PERIOD"].presence || "4").to_i.hours
  end

  def bypass_jira_email_address
    ENV["BYPASS_JIRA_EMAIL"]
  end

  def time_limit
    ENV.fetch("BUDDY_CHECK_TIME_LIMIT", ENV.fetch("DEPLOY_MAX_MINUTES_PENDING", 20)).to_i
  end

  def stop_expired_deploys
    Deploy.expired.each(&:stop!)
  end
end
