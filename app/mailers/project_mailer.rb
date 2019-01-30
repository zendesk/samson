# frozen_string_literal: true
class ProjectMailer < ApplicationMailer
  def created_email(to, user, project)
    build_mail user, project, to, 'created'
  end

  def deleted_email(to, user, project)
    build_mail user, project, to, 'deleted'
  end

  private

  def build_mail(user, project, address, action)
    subject = "Samson Project #{action.titleize}: #{project.name}"
    body = <<~TEXT
      "#{user.name_and_email} just #{action} project #{project.name}
      #{project.url}
      #{project.repository_homepage}
    TEXT
    mail(to: address, subject: subject, body: body)
  end
end
