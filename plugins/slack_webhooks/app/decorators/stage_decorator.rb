# frozen_string_literal: true
Stage.class_eval do
  has_many :slack_webhooks, dependent: :destroy
  accepts_nested_attributes_for :slack_webhooks, allow_destroy: true, reject_if: ->(a) { a.fetch(:webhook_url).blank? }
end
