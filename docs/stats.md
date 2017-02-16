# Instrumentation

### StatsD

Samson sends StatsD web request metrics and metrics about deploys and threads
in use. Statsd silently disables itself if no agent is running on the host. All
metrics collected are prepending with 'samson.app'.

<img src="/docs/images/datadog.png?raw=true" width="600">

### NewRelic

If a `NEW_RELIC_LICENSE_KEY` and `NEW_RELIC_APP_NAME` are set, then performance stats will be sent to [NewRelic](https://newrelic.com/),
for more details see [Agent configuration](https://docs.newrelic.com/docs/agents/ruby-agent/configuration/ruby-agent-configuration).
