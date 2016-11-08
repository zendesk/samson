# frozen_string_literal: true
module AuditLog
  extend ActiveSupport::Concern
  VALID_METHODS = [:info, :warn, :debug, :error]

  private

  def auditLog(user, action, args)
    auditLogger(:info, user, action, args)
  end

  def auditInfo(user, action, args)
    auditLogger(:info, user, action, args)
  end

  def auditWarn(user, action, args)
    auditLogger(:warn, user, action, args)
  end

  def auditDebug(user, action, args)
    auditLogger(:debug, user, action, args)
  end

  def auditError(user, action, args)
    auditLogger(:error, user, action, args)
  end

  def auditLogger(level, user, action, args)
    if AUDIT_LOGGER && VALID_METHODS.include?(level)
      message = {}
      message.user = AuditPresenter.present(user)
      message.time = Time.now
      message.action = action
      i = 0
      for arg in args
        message[subject+i] = AuditPresenter.present(arg)
        i += 1
      end

      AUDIT_LOGGER.send(level, message)
    end
  end
end
