class DeployMailer < ActionMailer::Base
  default from: "deploys@zendesk.com"

  def deploy_email(stage, deploy)
    @project = stage.project
    @deploy = deploy
    @user = current_user

    mail(to: stage.notify_email_address, subject: "[ZD DEPLOY] deploy.summary")
  end
end
