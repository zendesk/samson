module SamsonAudit
  extend ActiveSupport::Concern
  include CurrentUser

  mattr_accessor :original_attributes

  def prepare_audit(subject)
    self.original_attributes = subject.to_auditable_json if is_auditable(subject)
  end

  def audit(subject)
    case action_name
    when 'create' then
      audit_create(action_name, subject)
    when 'destroy' then
      audit_destroy(action_name, subject)
    when 'update' then
      audit_update(action_name, subject)
    else
      raise "Unsupported action: #{action_name}"
    end
  end

  private

  def audit_create(action, subject)
    audit_action(action, subject, after: subject.to_auditable_json) if is_auditable(subject)
  end

  def audit_destroy(action, subject)
    audit_action(action, subject, before: subject.to_auditable_json) if is_auditable(subject)
  end

  def audit_update(action, subject)
    audit_action(action, subject, before: original_attributes, after: subject.to_auditable_json) if is_auditable(subject)
  end

  def audit_action(action, subject, before: {}, after: {})
    Rails.logger.info(JSON.pretty_generate(audit_object(action, after, before, subject)))
  end

  def is_auditable(subject)
    subject.respond_to? :to_auditable_json
  end

  def audit_object(action, after, before, subject)
    {
      logtype: 'AUDIT',
      logged_at: "#{Time.now.getutc}",
      user: "#{current_user.name_and_email}",
      object: "#{subject.class.name}",
      action: "#{action}",
      before: "#{before}",
      after: "#{after}"
    }
  end
end
