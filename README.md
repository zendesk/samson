**Use of this software is subject to important terms and conditions as set forth in the License file**

## Samson

[![Build Status](https://travis-ci.org/zendesk/samson.svg?branch=master)](https://travis-ci.org/zendesk/samson)

[![DockerHub Status](https://dockeri.co/image/zendesk/samson)](https://hub.docker.com/r/zendesk/samson)

### What?

A web interface for deployments.

**View the current status of all your projects:**

![](http://f.cl.ly/items/3n0f0m3j2Q242Y1k311O/Samson.png)

**Allow anyone to watch deploys as they happen:**

![](http://cl.ly/image/1m0Q1k2r1M32/Master_deploy__succeeded_.png)

**View all recent deploys across all projects:**

![](http://cl.ly/image/270l1e3s2e1p/Samson.png)

### How?

Samson works by ensuring a git repository for a project is up-to-date, and then executes the commands associated with a stage. If you want to find out exactly what's going on, have a read through [JobExecution](app/models/job_execution.rb).

Streaming is done through a [controller](app/controllers/streams_controller.rb) that uses [server-sent events](https://en.wikipedia.org/wiki/Server-sent_events) to display to the client.

#### Requirements

* MySQL, Postgresql, or SQLite
* Memcache
* Ruby (>= 2.1.1)
* Git (>= 1.7.2)

### Documentation

* [Getting started](docs/setup.md)
* [Permissions](docs/permissions.md)
* [Continuous Integration](docs/ci.md)
* [Extra features](docs/extra_features.md)
* [Plugins](docs/plugins.md)
* [Getting statistics](docs/stats.md)

### Contributing

Improvements are always welcome. Please follow these steps to contribute

1. Submit a Pull Request with a detailed explaination of changes and screenshots (if UI is changing)
1. Receive a :+1: from a core team member
1. Core team will merge your changes

### Team

Core team is [@steved](https://github.com/steved), [@dasch](https://github.com/dasch), [@jwswj](https://github.com/jwswj), [@halcyonCorsair](https://github.com/halcyonCorsair), [@princemaple](https://github.com/princemaple), [@bolddane](https://github.com/bolddane), [@pswadi-zendesk](https://github.com/pswadi-zendesk), [@henders](https://github.com/henders).
