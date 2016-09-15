Notify airbrake after deploys if, to resolve all old errors if:
 - deploy groups are used
 - deploy was a success
 - stage has notify_airbrake enabled
 - environment name is simple / looks like a rail env (staging/production)
 - `airbrake_api_key` is set as secret for the given project/deploy-group
