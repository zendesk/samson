# frozen_string_literal: true
class AccessRequestMailer < ApplicationMailer
  def access_request_email(options)
    @host = options.fetch(:host)
    @user = options.fetch(:user)
    @manager_email = options.fetch(:manager_email)
    @reason = options.fetch(:reason)
    @projects = Project.order(:name).find(options.fetch(:project_ids))
    @role = Role.find(options.fetch(:role_id))
    mail(from: @user.email, to: build_to, cc: build_cc, subject: build_subject, body: build_body)
  end

  private

  def build_to
    # send to manager if no primary recipients configured
    ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'].presence&.split || @manager_email
  end

  def build_cc
    (ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'].present? ? [@manager_email] : []) << @user.email
  end

  def build_subject
    subject = []
    subject << "[#{ENV['REQUEST_ACCESS_EMAIL_PREFIX']}]" if ENV['REQUEST_ACCESS_EMAIL_PREFIX'].present?
    subject << "Grant #{@role.display_name} access rights to #{@user.name}"
    subject.join ' '
  end

  def build_body
    message = []
    message << "Please bump access rights for user #{@user.name_and_email} on #{@host}."
    message << ""
    message << "Desired role: #{@role.display_name}"
    message << "Target projects:"
    @projects.each { |project| message << "  - #{project.name}" }
    message << ""
    message << "Reason: #{@reason}"
    message << "Manager: #{@manager_email}" if @manager_email
    message.join "\n"
  end
end
