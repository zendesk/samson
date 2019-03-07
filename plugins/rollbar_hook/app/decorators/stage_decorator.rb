# frozen_string_literal: true
Stage.class_eval do
  has_many :rollbar_webhooks, dependent: :destroy
  accepts_nested_attributes_for :rollbar_webhooks, allow_destroy: true, reject_if: ->(a) {
    a.fetch(:webhook_url).blank?
  }
end
