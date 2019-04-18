# frozen_string_literal: true
class DeployMailer < ApplicationMailer
  add_template_helper(DeploysHelper)
  add_template_helper(ApplicationHelper)

  def deploy_email(deploy, emails)
    prepare_mail(deploy)

    mail(to: emails, subject: deploy_subject(deploy))
  end

  def bypass_email(deploy, user)
    prepare_mail(deploy)
    mail(
      subject: "[BYPASS]#{deploy_subject(deploy)}",
      to: Samson::BuddyCheck.bypass_email_addresses,
      cc: user.email
    )
  end

  def deploy_failed_email(deploy, emails)
    prepare_mail(deploy)

    mail(
      to: emails,
      subject: "[AUTO-DEPLOY]#{deploy_subject(deploy)}",
      template_name: "deploy_email"
    )
  end

  private

  def deploy_subject(deploy)
    "[#{Rails.application.config.samson.email.prefix}][##{deploy.id}] #{deploy.summary(show_project: true)}"
  end

  def prepare_mail(deploy)
    @deploy = deploy
    @project = @deploy.stage.project
    @changeset = @deploy.changeset
  end
end
