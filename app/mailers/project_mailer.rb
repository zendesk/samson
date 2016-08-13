# frozen_string_literal: true
class ProjectMailer < ApplicationMailer
  def created_email(user, project)
    address = Rails.application.config.samson.project_created_email
    subject = "Samson Project Created: #{project.name}"
    body = "#{user.name_and_email} just created a new project #{project.name}"
    mail(to: address, subject: subject, body: body)
  end

  def deleted_email(user, project)
    address = Rails.application.config.samson.project_deleted_email
    subject = "Samson Project Deleted: #{project.name}"
    body = "#{user.name_and_email} just deleted project #{project.name}"
    mail(to: address, subject: subject, body: body)
  end
end
