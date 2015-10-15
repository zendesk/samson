class AccessRequestMailer < ApplicationMailer
  def access_request_email(host, user, manager_email, reason)
    @host = host
    @user = user
    @manager_email = manager_email
    @reason = reason
    mail(to: build_recipients, subject: build_subject, body: build_body)
  end

  private

  def build_recipients
    recipients = ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'].present? ? ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'].split : []
    recipients << @manager_email
  end

  def build_subject
    subject = []
    subject << "[#{ENV['REQUEST_ACCESS_EMAIL_PREFIX']}]" if ENV['REQUEST_ACCESS_EMAIL_PREFIX'].present?
    subject << "Grant #{desired_role} access rights to #{@user.name}"
    subject.join ' '
  end

  def build_body
    "Please bump access rights to #{desired_role} on #{@host} for #{@user.name_and_email}\n\nReason:\n#{@reason}"
  end

  def desired_role
    Role.find(@user.role_id + 1).name
  end
end
