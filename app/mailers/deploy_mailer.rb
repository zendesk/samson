class DeployMailer < ApplicationMailer

  add_template_helper(DeploysHelper)
  add_template_helper(ApplicationHelper)

  def deploy_email(stage, deploy)
    prepare_mail(stage, deploy)

    mail(to: stage.notify_email_addresses, subject: deploy_subject(deploy))
  end

  def bypass_email(stage, deploy, user)
    prepare_mail(stage, deploy)

    subject = "[BYPASS]#{deploy_subject(deploy)}"

    to_email = [BuddyCheck.bypass_email_address]
    to_email << BuddyCheck.bypass_jira_email_address if BuddyCheck.bypass_jira_email_address

    cc_email = [user.email, BuddyCheck.bypass_retroactive_approval_email]
    mail(to: to_email, cc: cc_email, subject: subject)
  end

  def deploy_failed_email(stage, deploy, emails)
    prepare_mail(stage, deploy)

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

  def prepare_mail(stage, deploy)
    @project = stage.project
    @deploy = deploy
    @changeset = @deploy.changeset
  end
end
