# frozen_string_literal: true
Stage.class_eval do
  has_many :flowdock_flows, dependent: :destroy

  accepts_nested_attributes_for :flowdock_flows, allow_destroy: true, reject_if: :no_flowdock_token?

  def send_flowdock_notifications?
    flowdock_flows.any?
  end

  def flowdock_tokens
    flowdock_flows.map(&:token)
  end

  def no_flowdock_token?(flowdock_attrs)
    flowdock_attrs['token'].blank?
  end
end
