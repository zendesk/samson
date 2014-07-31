class DeployMailer < ActionMailer::Base
  default from: "deploys@samson-deployment.com"

  add_template_helper(DeploysHelper)
  add_template_helper(ApplicationHelper)

  def deploy_email(stage, deploy)
    prepare_mail(stage, deploy)

    subject =  "[#{Rails.application.config.samson.email_prefix}] #{deploy.summary_for_email}"

    mail(to: stage.notify_email_addresses, subject: subject)
  end

  def bypass_email(stage, deploy, user)
    prepare_mail(stage, deploy)

    subject = "[BYPASS][#{Rails.application.config.samson.email_prefix}] #{deploy.summary_for_email}"

    to_email = [BuddyCheck.bypass_email_address]
    to_email << BuddyCheck.bypass_jira_email_address if BuddyCheck.jira_email_required?

    mail(to: to_email, cc: user.email, subject: subject)
  end

  private

  def prepare_mail(stage, deploy)
    @project = stage.project
    @deploy = deploy
    @changeset = Changeset.find(@project.github_repo, @deploy.previous_commit, @deploy.commit)
  end
end
