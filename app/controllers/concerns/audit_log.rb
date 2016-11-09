# frozen_string_literal: true
module AuditLog
  extend ActiveSupport::Concern

  private

  class Audit
    VALID_METHODS = [:info, :warn, :debug, :error]

    def self.log(user, action, *args)
      logger(:info, user, action, args)
    end

    def self.info(user, action, *args)
      logger(:info, user, action, args)
    end

    def self.warn(user, action, *args)
      logger(:warn, user, action, args)
    end

    def self.debug(user, action, *args)
      logger(:debug, user, action, args)
    end

    def self.error(user, action, *args)
      logger(:error, user, action, args)
    end

    def self.logger(level, user, action, *args)
      if AUDIT_LOGGER && VALID_METHODS.include?(level)
        message = {}
        message[:user] = AuditPresenter.present(user)
        message[:time] = Time.now
        message[:action] = action
        args[0].each_with_index do |arg, i|
          message['subject' + i.to_s] = AuditPresenter.present(arg)
        end
        AUDIT_LOGGER.send(level, message)
      end
    end
  end
end
