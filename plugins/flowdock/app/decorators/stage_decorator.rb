Stage.class_eval do
  has_many :flowdock_flows

  accepts_nested_attributes_for :flowdock_flows, allow_destroy: true, reject_if: :no_flowdock_token?

  def send_flowdock_notifications?
    flowdock_flows.enabled.any?
  end

  def flowdock_tokens
    flowdock_flows.map(&:token)
  end

  def no_flowdock_token?(flowdock_attrs)
    flowdock_attrs['token'].blank?
  end

  def enabled_flows_names
    flowdock_flows.enabled.map(&:name)
  end
end
