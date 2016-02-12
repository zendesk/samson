module Watchers
  module TopicSubscription
    def self.pod_updates_topic(unique_identifier)
      "pod-updates-#{unique_identifier}"
    end
  end
end
