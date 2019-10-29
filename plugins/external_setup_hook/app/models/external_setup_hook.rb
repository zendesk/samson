# frozen_string_literal: true

class ExternalSetupHook < ActiveRecord::Base
  validates :name, presence: true

  validate :validate_endpoint

  has_many :stage_external_setup_hooks, dependent: :destroy
  has_many :stages, through: :stage_external_setup_hooks, dependent: :destroy

  def validate_endpoint
    errors.add(:auth_type, "is unsupported") if auth_type.downcase! != 'token'

    valid = endpoint&.start_with?('http') &&
      begin
        URI.parse(endpoint)
      rescue URI::InvalidURIError
        false
      end

    errors.add(:endpoint, "is invalid") unless valid
  end
end
