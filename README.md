![](https://github.com/zendesk/samson/raw/master/app/assets/images/logo_light.png)

[![Build Status](https://travis-ci.org/zendesk/samson.svg?branch=master)](https://travis-ci.org/zendesk/samson)
[![Code Climate](https://codeclimate.com/repos/53340bef6956800b9000675c/badges/c7c44f80cff049aef8f7/gpa.svg)](https://codeclimate.com/repos/53340bef6956800b9000675c/feed)
[![Test Coverage](https://codeclimate.com/repos/53340bef6956800b9000675c/badges/c7c44f80cff049aef8f7/coverage.svg)](https://codeclimate.com/repos/53340bef6956800b9000675c/coverage)
[![DockerHub Status](https://img.shields.io/docker/stars/zendesk/samson.svg)](https://hub.docker.com/r/zendesk/samson)

[Demo](https://samson-demo.herokuapp.com)

### What?

A web interface for deployments.

**View the current status of all your projects:**

![](http://f.cl.ly/items/3n0f0m3j2Q242Y1k311O/Samson.png)

**Allow anyone to watch deploys as they happen:**

![](http://cl.ly/image/1m0Q1k2r1M32/Master_deploy__succeeded_.png)

**View all recent deploys across all projects:**

![](http://cl.ly/image/270l1e3s2e1p/Samson.png)

### How?

Samson works by ensuring a git repository for a project is up-to-date, and then executes the commands associated with a stage. If you want to find out exactly what's going on, have a read through [JobExecution](https://github.com/zendesk/samson/blob/master/app/models/job_execution.rb).

Streaming is done through a [controller](app/controllers/streams_controller.rb) that uses [server-sent events](https://en.wikipedia.org/wiki/Server-sent_events) to display to the client.

#### Requirements

* MySQL, Postgresql, or SQLite
* Memcache
* Ruby (>= 2.1.1)
* Git (>= 1.7.2)

### Documentation

* [Getting started](https://github.com/zendesk/samson/blob/master/docs/setup.md)
* [Permissions](https://github.com/zendesk/samson/blob/master/docs/permissions.md)
* [Continuous Integration](https://github.com/zendesk/samson/blob/master/docs/ci.md)
* [Extra features](https://github.com/zendesk/samson/blob/master/docs/extra_features.md)
* [Plugins](https://github.com/zendesk/samson/blob/master/docs/plugins.md)
* [Getting statistics](https://github.com/zendesk/samson/blob/master/docs/stats.md)

### Contributing

Improvements are always welcome. Please follow these steps to contribute

1. Submit a Pull Request with a detailed explanation of changes and screenshots (if UI is changing)
1. Receive a :+1: from a core team member
1. Core team will merge your changes

### Team

Core team is [@dasch](https://github.com/dasch), [@jwswj](https://github.com/jwswj), [@henders](https://github.com/henders),
[@grosser](https://github.com/grosser), [@jonmoter](https://github.com/jonmoter), [@msufa](https://github.com/msufa), [@sbrnunes](https://github.com/sbrnunes).

Support can be found on our [mailing list](https://groups.google.com/forum/#!forum/samson-users) `samson-users@googlegroups.com`.

### License

Use of this software is subject to important terms and conditions as set forth in the [LICENSE](LICENSE) file
