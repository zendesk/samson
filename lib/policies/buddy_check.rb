class BuddyCheck

  def self.enabled?
    "1" == ENV["BUDDY_CHECK_FEATURE"]
  end

  def self.bypass_email_address
    ENV["BYPASS_EMAIL"]
  end

  def self.bypass_jira_email_address
    ENV["BYPASS_JIRA_EMAIL"]
  end

  def self.deploy_max_minutes_pending
    ENV["DEPLOY_MAX_MINUTES_PENDING"].to_i
  end

  def self.stop_expired_deploys
    expired_deploys = Deploy.expired
    expired_deploys.each &:stop!
  end

end
