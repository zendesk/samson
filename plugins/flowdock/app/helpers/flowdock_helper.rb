module FlowdockHelper
  def default_flowdock_message(deploy)
    ":pray: #{deploy.user.name} is requesting approval for deploy #{project_deploy_url(deploy.project, deploy)}"
  end
end
