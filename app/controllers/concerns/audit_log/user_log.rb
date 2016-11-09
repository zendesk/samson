# frozen_string_literal: true
module AuditLog::UserLog
  extend ActiveSupport::Concern

  included do
    after_action :log_change, only: :update
    after_action :log_destroy, only: :destroy
  end

  private

  def log_change
    AuditLog::Audit.info(current_user, 'updated', user, user.role)
  end

  def log_destroy
    AuditLog::Audit.warn(current_user, 'destroyed', user)
  end
end
