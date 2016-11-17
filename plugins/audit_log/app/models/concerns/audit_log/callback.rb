# frozen_string_literal: true
module AuditLog::Callback
  def self.included(base)
    base.after_create_commit { |object| audit_log 'created', object }
    base.after_destroy_commit { |object| audit_log 'deleted', object }
    base.after_update_commit { |object| audit_log (object.try(:deleted_at) ? 'deleted' : 'updated'), object }
  end

  protected

  def audit_log(action, object)
    SamsonAuditLog::Audit.log(
      :info,
      PaperTrail.whodunnit_user || PaperTrail.whodunnit,
      "#{action} #{object.class.name}",
      object
    )
  end
end
