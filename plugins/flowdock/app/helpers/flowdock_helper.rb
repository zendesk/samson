module FlowdockHelper
  def default_flowdock_message(deploy)
    ":pray: #{user_tag(deploy.user)} is requesting approval for deploy #{project_deploy_url(deploy.project, deploy)}"
  end

  def user_tag(user)
    "@#{user.email.split('@').first}"
  end
end
