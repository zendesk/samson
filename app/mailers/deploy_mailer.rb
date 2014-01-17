class DeployMailer < ActionMailer::Base
  default from: "deploys@zendesk.com"

  def deploy_email(stage, deploy)
    @project = stage.project
    @deploy = deploy

    subject =  "[#{Rails.application.config.pusher.email_prefix}] #{deploy.summary_for_email}"

    mail(to: stage.notify_email_address, subject: subject)
  end
end
