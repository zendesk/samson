module FlowdockHelper
  def default_flowdock_message(deploy)
    project = deploy.project
    ":pray: @team #{deploy.user.name} is requesting approval" \
      " to deploy #{project.name} **#{deploy.reference}** to production."\
      " [Review this deploy](#{project_deploy_url(project, deploy)})."
  end
end
