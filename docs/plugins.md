# Plugins

Samson now supports writing plugins to add functionality to the core app keeping the core isolated and simpler. You can
thus add UI elements to pages that support it, and hook into events such as before and after deploys.

To get started execute the following and follow the on-screen instructions:
```
rails generate plugin MyCoolNewPlugin
```

Also feel free to browse the existing plugins in the 'plugins' directory to get a feel. They follow the structure of a 
Rails Engine.

Current Plugins:

* Environment variables per project
* Flowdock
* [Hipchat](https://github.com/listia/samson_hipchat): Clone of Slack plugin
* Jenkins
* Pipelines
* [ReleaseNumberFromCI](https://github.com/redbubble/samson-release-number-from-ci): A plugin which supports setting specific release number for samson release from CI
* Slack

## Enabling Plugins

To specify which plugins you want to run, Samson looks at the `PLUGINS` environment
variable. Through this mechanism, you can enable and disable plugins.

To selectively enable plugins, you can pass a comma-separated list:

`PLUGINS="flowdock,env,slack"`

To enable all plugins, use a value of "all":

`PLUGINS="all"`

To selectively disable plugins, use "all", and then a comma-separated list of
plugins, with a minus sign in front of each:

`PLUGINS="all,-flowdock,-slack"`
