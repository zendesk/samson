# Plugins

Plugins keep the core of samson clean. 

They are rails engines that can use [supported hooks](https://github.com/zendesk/samson/blob/master/lib/samson/hooks.rb#L7-L67)
to add custom logic / UI and decorators to enhance supported models/controllers (without eager loading them in development).

Available plugins:

 - [Airbrake notification on deploy](https://github.com/zendesk/samson/tree/master/plugins/airbrake_hook)
 - [Airbrake error handling](https://github.com/zendesk/samson/tree/master/plugins/airbrake)
 - [AWS ECR credential refresher](https://github.com/zendesk/samson/tree/master/plugins/aws_ecr)
 - [AWS STS Tokens](https://github.com/zendesk/samson/tree/master/plugins/aws_sts)
 - [Datadog monitoring and deploy tracking](https://github.com/zendesk/samson/tree/master/plugins/datadog)
 - [Datadog APM tracer](https://github.com/zendesk/samson/tree/master/plugins/datadog_tracer)
 - [ENV var management](https://github.com/zendesk/samson/tree/master/plugins/env)
 - [Flowdock notification](https://github.com/zendesk/samson/tree/master/plugins/flowdock)
 - [Github](https://github.com/zendesk/samson/tree/master/plugins/github)
 - [Gcloud](https://github.com/zendesk/samson/tree/master/plugins/gcloud)
 - [Jenkins jobs management](https://github.com/zendesk/samson/tree/master/plugins/jenkins)
 - [Jenkins Status Checker](https://github.com/zendesk/samson/tree/master/plugins/jenkins_status_checker)
 - [JIRA](https://github.com/zendesk/samson/tree/master/plugins/jira)
 - [Hipchat notification](https://github.com/listia/samson_hipchat)
 - [Kubernetes](https://github.com/zendesk/samson/tree/master/plugins/kubernetes)
 - [Ledger](https://github.com/zendesk/samson/tree/master/plugins/ledger)
 - [Release Number From CI](https://github.com/redbubble/samson-release-number-from-ci)
 - [NewRelic](https://github.com/zendesk/samson/tree/master/plugins/new_relic)
 - [Pipelined deploys](https://github.com/zendesk/samson/tree/master/plugins/pipelines)
 - [Sentry](https://github.com/zendesk/samson/tree/master/plugins/sentry)
 - [Slack deploys](https://github.com/zendesk/samson/tree/master/plugins/slack_app)
 - [Slack notifications](https://github.com/zendesk/samson/tree/master/plugins/slack_webhooks)
 - [Zendesk notifications](https://github.com/zendesk/samson/tree/master/plugins/zendesk)
 - [Rollbar notifications on deploy](https://github.com/zendesk/samson/tree/master/plugins/rollbar_hook)
 - [Rollbar dashboards](https://github.com/zendesk/samson/tree/master/plugins/rollbar_dashboards)
 - [Assertible notifications on deploy](https://github.com/zendesk/samson/tree/master/plugins/assertible)
 - [Prerequisite stages](https://github.com/zendesk/samson/tree/master/plugins/prerequisite_stages)
 - [GitLab](https://github.com/zendesk/samson/tree/master/plugins/gitlab)
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
