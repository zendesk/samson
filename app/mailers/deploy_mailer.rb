class DeployMailer < ActionMailer::Base
  default from: "deploys@example.com"

  def deploy_email(stage, deploy, job)
    @project = stage.project
    @deploy = deploy

    mail(to: stage.notify_email_address, subject: deploy.summary)
  end
end
