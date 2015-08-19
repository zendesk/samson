# Instrumentation

Samson sends StatsD basic web request metrics and metrics about deploys and threads
in use. Statsd silently disables itself if no agent is running on the host. All
metrics collected are prepending with 'samson.app'.

<img src="/docs/images/datadog.png?raw=true" width="600">
