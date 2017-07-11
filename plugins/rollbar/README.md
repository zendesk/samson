# Rollbar Plugin

This plugin adds deploy tracking to [Rollbar](https://rollbar.com/)

1. Add `https://api.rollbar.com/api/1/deploy/` to the the webhook URL, unless you're using a self-hosted instance of Rollbar.
2. Sign in to Rollbar and go to the "Deploys" area.
3. c/p the `access_token` to Samson.
4. The `environment` name must match one from Rollbar "Settings > General > Environments".
