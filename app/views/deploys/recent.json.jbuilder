json.array! @deploys do |deploy|
  json.deployId(deploy.id)
  json.gravatarURL(deploy.user.gravatar_url)
  json.projectId(deploy.project.id)
  json.projectName(deploy.project.name)
  json.projectURLParam(deploy.project.to_param)
  json.reference(deploy.reference)
  json.stageName(deploy.stage.name)
  json.stageType(!!deploy.stage.confirm)
  json.status(deploy.status)
  json.time(datetime_to_js_ms deploy.updated_at)
  json.timeAgo(time_ago_in_words deploy.updated_at)
  json.user(deploy.user.name)
end
