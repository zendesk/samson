class DeployMailer < ActionMailer::Base
  default from: "deploys@samson-deployment.com"

  add_template_helper(DeploysHelper)
  add_template_helper(ApplicationHelper)

  def deploy_email(stage, deploy)
    prepare_mail(stage, deploy)

    subject =  "[#{Rails.application.config.samson.email_prefix}] #{deploy.summary_for_email}"

    mail(to: stage.notify_email_addresses, subject: subject)
  end

  def bypass_email(stage, deploy)
    prepare_mail(stage, deploy)

    subject = "[BYPASS][#{Rails.application.config.samson.email_prefix}] #{deploy.summary_for_email}"

    # the receiver is to be changed, and should be always present, where notify_email

    mail(to: BuddyCheck.bypass_email_address, subject: subject)
  end

  private

  def prepare_mail(stage, deploy)
    @project = stage.project
    @deploy = deploy
    @changeset = Changeset.find(@project.github_repo, @deploy.previous_commit, @deploy.commit)
  end
end
