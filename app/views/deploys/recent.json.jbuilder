json.array! @deploys do |deploy|
  json.time(datetime_to_js_ms deploy.updated_at)
  json.projectName(deploy.project.name)
  json.gravatarURL(deploy.user.gravatar_url)
  json.status(deploy.status)
  json.summary(deploy.summary)
end
