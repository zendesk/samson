json.array! @deploys do |deploy|
  json.time(datetime_to_js_ms deploy.updated_at)
  json.projectURLParam(deploy.project.to_param)
  json.projectName(deploy.project.name)
  json.projectId(deploy.project.id)
  json.user(deploy.user.name)
  json.stageType(!!deploy.stage.confirm)
  json.deployId(deploy.id)
  json.gravatarURL(deploy.user.gravatar_url)
  json.status(deploy.status)
  json.summary(deploy.summary)
end
