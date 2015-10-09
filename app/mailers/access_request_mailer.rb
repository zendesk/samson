class AccessRequestMailer < ApplicationMailer
  def access_request_email(host, user, manager_email, reason, project_ids)
    @host = host
    @user = user
    @manager_email = manager_email
    @reason = reason
    @projects = Project.order(:name).find(project_ids)
    mail(to: build_recipients, subject: build_subject, body: build_body)
  end

  private

  def build_recipients
    ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'].split << @manager_email
  end

  def build_subject
    "[#{ENV['REQUEST_ACCESS_EMAIL_PREFIX']}] Grant #{desired_role} access rights to #{@user.name}"
  end

  def build_body
    message = []
    message << "Please bump access rights for user #{@user.name_and_email} on #{@host}."
    message << ''
    message << "Desired role: #{desired_role}"
    message << 'Target projects:'
    @projects.each { |project| message << "  - #{project.name}" }
    message << ''
    message << "Reason: #{@reason}"
    message.join "\n"
  end

  def desired_role
    @user.is_super_admin? ? Role::SUPER_ADMIN.name : Role.find(@user.role_id + 1).name
  end
end
