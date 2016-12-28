Hyperclair will pull the image from registry and run scan with Clair scanner.
This is supposed to use a forked version with `ENV` var and `/` support.
https://github.com/zendesk/hyperclair
(discussion on why we use a fork / when we can switch see https://github.com/wemanity-belgium/hyperclair/pull/90)

Set `HYPERCLAIR_PATH` ENV variable in samson to enable.
