class DeployMailer < ActionMailer::Base
  default from: "deploys@samson-deployment.com"

  add_template_helper(DeploysHelper)
  add_template_helper(ApplicationHelper)

  def deploy_email(stage, deploy)
    @project = stage.project
    @deploy = deploy
    @changeset = Changeset.find(@project.github_repo, @deploy.previous_commit, @deploy.commit)

    subject =  "[#{Rails.application.config.samson.email_prefix}] #{deploy.summary_for_email}"

    mail(to: stage.notify_email_addresses, subject: subject)
  end
end
