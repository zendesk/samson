### Plugins

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
* Slack
