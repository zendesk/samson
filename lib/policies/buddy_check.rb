class BuddyCheck
  def self.enabled?
    "1" == ENV["BUDDY_CHECK_FEATURE"]
  end

  def self.bypass_email_address
    ENV["BYPASS_EMAIL"]
  end
end
