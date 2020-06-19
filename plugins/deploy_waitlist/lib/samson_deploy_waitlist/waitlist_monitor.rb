# frozen_string_literal: true
module SamsonDeployWaitlist
  class WaitlistMonitor
    TIME_TO_LOCK_QUEUE = 10

    def self.check_your_head
      Stage.all.each do |s|
        waitlist = Waitlist.new(s.project_id, s.id)
        next unless waitlist.head_updated_at.present? && waitlist.list.present?

        current_head = waitlist.list[0]

        next if s.lock.try(:user).try(:email) == current_head[:email]
        next unless TIME_TO_LOCK_QUEUE.minutes.ago > waitlist.head_updated_at.to_datetime

        # Current head of waitlist has been head for 5 minutes without locking the stage...
        # Kick 'em.
        waitlist.remove(0)
        waitlist.add(current_head)
      end
    end
  end
end
