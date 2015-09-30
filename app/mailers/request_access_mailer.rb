class RequestAccessMailer < ApplicationMailer
  def request_access_email(host, user)
    @host = host
    @user = user
    address_list = ENV['REQUEST_ACCESS_EMAIL_ADDRESS'].split(' ')
    mail(to: address_list, subject: build_subject, body: build_body)
  end

  private

  def build_subject
    "[#{ENV['REQUEST_ACCESS_EMAIL_PREFIX']}] Grant #{desired_role} access rights to #{@user.name}"
  end

  def build_body
    "Please bump access rights to #{desired_role} on #{@host} for #{@user.name_and_email}"
  end

  def desired_role
    Role.find(@user.role_id + 1).name
  end
end
