# Slack App Plugin

This plugin adds a `/deploy` command to Slack which creates Samson deployments.
To activate:

1. Go over to Slack and create a [new app](https://api.slack.com/apps/new). Many of the fields are completely up to you, but these are important:
  - Add `https://your.samson.tld/slack_app/oauth` as a redirect URI.
  - Enable interactive messages, and set the URI to `https://your.samson.tld/slack_app/interact`.
  - Add a `/deploy` slash-command, and set its URL to `https://your.samson.tld/slack_app/command`.
  - Grab the Client ID and secret and verification token, and record them in your environment as `SLACK_CLIENT_ID`, `SLACK_CLIENT_SECRET`, and `SLACK_VERIFICATION_TOKEN`.
2. Visit https://your.samson.tld/slack_app/oauth, and click the "Connect to Slack" button.
3. Switch back over to Slack, and try out the `/deploy` command!
