module SlackWebhooksHelper
  def default_slack_message(deploy)
    project = deploy.project
    ":pray: @here _#{deploy.user.name}_ is requesting approval" \
      " to deploy #{project.name} *#{deploy.reference}* to #{deploy.stage.name}.\n"\
      " Review this deploy: #{project_deploy_url(project, deploy)}"
  end
end
