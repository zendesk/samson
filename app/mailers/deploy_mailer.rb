class DeployMailer < ApplicationMailer

  add_template_helper(DeploysHelper)
  add_template_helper(ApplicationHelper)

  def deploy_email(deploy)
    prepare_mail(deploy)

    mail(to: deploy.stage.notify_email_addresses, subject: deploy_subject(deploy))
  end

  def bypass_email(deploy, user)
    prepare_mail(deploy)

    subject = "[BYPASS]#{deploy_subject(deploy)}"

    to_email = [BuddyCheck.bypass_email_address]
    to_email << BuddyCheck.bypass_jira_email_address if BuddyCheck.bypass_jira_email_address

    mail(to: to_email, cc: user.email, subject: subject)
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
    "[#{Rails.application.config.samson.email.prefix}] #{deploy.summary_for_email}"
  end

  def prepare_mail(deploy)
    @deploy = deploy
    @project = @deploy.stage.project
    @changeset = @deploy.changeset
  end
end
