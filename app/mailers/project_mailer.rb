class ProjectMailer < ApplicationMailer
  def created_email(user, project)
    address = ENV['PROJECT_CREATED_NOTIFY_ADDRESS']
    subject = "Samson Project Created: #{project.name}"
    body = "#{user.name_and_email} just created a new project #{project.name}"
    mail(to: address, subject: subject, body: body)
  end
end
