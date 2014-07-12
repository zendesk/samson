class BuddyCheck
  def self.enabled?
    "1" == ENV["BUDDY_CHECK_FEATURE"]
  end
end
