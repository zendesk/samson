# Rollbar Plugin

This plugin adds deploy tracking to [Rollbar](https://rollbar.com/)

1. The webhook URL is `https://api.rollbar.com/api/1/deploy/` unless it's a self-hosted instance.
2. Sign in to Rollbar and go to the "Deploys" area.
3. c/p the `access_token` to Samson.
4. The `environment` name must match one from Rollbar "Settings > General > Environments".
