module FlowdockHelper
  def default_flowdock_message(deploy)
    ":pray: @team #{deploy.user.name} is requesting approval to deploy #{deploy.project.name} **#{deploy.reference}** to production."\
    " [Approve this deploy](#{project_deploy_url(deploy.project, deploy)})."
  end
end
