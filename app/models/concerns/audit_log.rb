# frozen_string_literal: true
module AuditLog
  def self.included(base)
    base.after_create_commit do |object|
      SamsonAuditLog::Audit.log(:info, PaperTrail.whodunnit, "created #{object.class.name}", object)
    end
    base.after_destroy_commit do |object|
      SamsonAuditLog::Audit.log(:info, PaperTrail.whodunnit, "deleted #{object.class.name}", object)
    end
    base.after_update_commit do |object|
      if object.try(:deleted_at)
        SamsonAuditLog::Audit.log(:info, PaperTrail.whodunnit, "deleted #{object.class.name}", object)
      else
        SamsonAuditLog::Audit.log(:info, PaperTrail.whodunnit, "updated #{object.class.name}", object)
      end
    end
  end
end
