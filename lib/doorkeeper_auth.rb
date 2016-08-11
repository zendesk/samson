# frozen_string_literal: true
module DoorkeeperAuth
  class DisallowedAccessError < StandardError; end

  def self.included(base)
    base.extend ClassMethods

    base.class_attribute :api_accessible, instance_accessor: false
    base.before_action :access_denied!, if: :disallowed?
  end

  private

  def access_denied!
    raise(DisallowedAccessError, "This resource is not accessible via the API")
  end

  def disallowed?
    return false unless request.env['warden'] && request.env['warden'].winning_strategy == :doorkeeper
    return true unless self.class.api_accessible
    !request.fullpath.include?("/api/")
  end

  module ClassMethods
    def api_accessible!(setting)
      self.api_accessible = setting
    end
  end
end
