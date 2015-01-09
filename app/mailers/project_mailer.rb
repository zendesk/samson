class ProjectMailer < ApplicationMailer
  layout 'mailer'

  def created_email(user, project)
    mail(to: ENV['PROJECT_CREATED_NOTIFY_ADDRESS'], subject: "Samson Project Created: #{project.name}", body: "#{user.name_and_email} just created a new project #{project.name}")
  end
end
