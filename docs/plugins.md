# Plugins

Plugins enable the core of samson to stay clean, they can add UI elements to pages that support it,
and hook into events such as before and after deploys see
[supported hooks](https://github.com/zendesk/samson/blob/master/lib/samson/hooks.rb#L7-L43).

Each plugin is a rails engine.

Available plugins:

 - [Airbrake notification on deploy](https://github.com/zendesk/samson/tree/master/plugins/airbrake)
 - [AWS ECR credential refresher](https://github.com/zendesk/samson/tree/master/plugins/aws_ecr)
 - [Datadog monitoring and deploy tracking](https://github.com/zendesk/samson/tree/master/plugins/datadog)
 - [Docker binary builder](https://github.com/zendesk/samson/tree/master/plugins/docker_binary_builder)
 - [Dockerfile.erb](https://github.com/zendesk/samson/tree/master/plugins/dockerb)
 - [ENV var management](https://github.com/zendesk/samson/tree/master/plugins/env)
 - [Flowdock notification](https://github.com/zendesk/samson/tree/master/plugins/flowdock)
 - [Github](https://github.com/zendesk/samson/tree/master/plugins/github)
 - [Gcloud](https://github.com/zendesk/samson/tree/master/plugins/gcloud)
 - [Jenkins jobs management](https://github.com/zendesk/samson/tree/master/plugins/jenkins)
 - [Hipchat notification](https://github.com/listia/samson_hipchat)
 - [Kubernetes](https://github.com/zendesk/samson/tree/master/plugins/kubernetes)
 - [Release Number From CI](https://github.com/redbubble/samson-release-number-from-ci)
 - [NewRelic monitoring](https://github.com/zendesk/samson/tree/master/plugins/new_relic)
 - [Pipelined deploys](https://github.com/zendesk/samson/tree/master/plugins/pipelines)
 - [Slack deploys](https://github.com/zendesk/samson/tree/master/plugins/slack_app)
 - [Slack notifications](https://github.com/zendesk/samson/tree/master/plugins/slack_webhooks)
 - [Zendesk notifications](https://github.com/zendesk/samson/tree/master/plugins/zendesk)
 - [Rollbar notifications on deploy](https://github.com/zendesk/samson/tree/master/plugins/rollbar)
 - [Assertible notifications on deploy](https://github.com/zendesk/samson/tree/master/plugins/assertible)
 - Add yours here!

To create your own plugin run:
```
rails generate plugin MyCoolNewPlugin
```

## Enabling Plugins

The `PLUGINS` environment variable decides which plugins are enabled.

Use a comma-separated list:

`PLUGINS="flowdock,env,slack_webhooks"`

To enable all plugins, use "all":

`PLUGINS="all"`

To disable selected plugins, use "all", and a comma-separated list of plugins, with a minus sign in front of each:

`PLUGINS="all,-flowdock,-slack_webhooks"`
