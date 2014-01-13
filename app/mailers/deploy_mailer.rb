class DeployMailer < ActionMailer::Base
  default from: "deploys@zendesk.com"

  def deploy_email(stage, deploy)
    @project = stage.project
    @deploy = deploy

    mail(to: stage.notify_email_address, subject: deploy.summary)
  end
end
