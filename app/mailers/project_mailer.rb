# frozen_string_literal: true
class ProjectMailer < ApplicationMailer
  def created_email(user, project)
    build_mail user, project, Rails.application.config.samson.project_created_email, 'created'
  end

  def deleted_email(user, project)
    build_mail user, project, Rails.application.config.samson.project_deleted_email, 'deleted'
  end

  private

  def build_mail(user, project, address, action)
    subject = "Samson Project #{action.titleize}: #{project.name}"
    body = "#{user.name_and_email} just #{action} project #{project.name}"
    mail(to: address, subject: subject, body: body)
  end
end
