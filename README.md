![](https://github.com/zendesk/samson/raw/master/app/assets/images/logo_light.png)

[![Build Status](https://travis-ci.org/zendesk/samson.svg?branch=master)](https://travis-ci.org/zendesk/samson)
[![DockerHub Status](https://img.shields.io/docker/stars/zendesk/samson.svg)](https://hub.docker.com/r/zendesk/samson)
[![FOSSA Status](https://app.fossa.io/api/projects/custom%2B4071%2Fgit%40github.com%3Azendesk%2Fsamson.git.svg?type=shield)](https://app.fossa.io/projects/custom%2B4071%2Fgit%40github.com%3Azendesk%2Fsamson.git?ref=badge_shield)

Samson is a web interface for deployments. [Live Demo](https://samson-demo.herokuapp.com)

**View the current status of all your projects:**

![](http://f.cl.ly/items/3n0f0m3j2Q242Y1k311O/Samson.png)

**Allow anyone to watch deploys as they happen:**

![](http://cl.ly/image/1m0Q1k2r1M32/Master_deploy__succeeded_.png)

**View all recent deploys across all projects:**

![](http://cl.ly/image/270l1e3s2e1p/Samson.png)

### Deployment Workflow

Create a project and 1 or more stages (staging/production etc),
then selects a version and start the deploy.

Samson will:
 - clone git repository
 - execute commands associated with the stage (or execute API calls for kubernetes)
 - stream deploy output to everybody who wants to watch
 - persist deploy output for future review

#### Requirements

* MySQL, Postgresql, or SQLite
* Ruby (see .ruby-version)
* Git (>= 1.7.2)

### Documentation

* [Getting started](/docs/setup.md)
* [Permissions](/docs/permissions.md)
* [Continuous Integration](/docs/ci.md)
* [Extra features](/docs/extra_features.md)
* [Plugins](/docs/plugins.md)
* [Statistics](/docs/stats.md)
* [API](/docs/api.md)

### Contributing

Improvements are always welcome. Please follow these steps to contribute

1. Submit a Pull Request with a detailed explanation of changes and screenshots (if UI is changing)
1. Receive a :+1: from a core team member
1. Core team will merge your changes

### Team

Core team is [@henders](https://github.com/henders), [@grosser](https://github.com/grosser), [@jonmoter](https://github.com/jonmoter), [@irwaters](https://github.com/irwaters).

### License

Use of this software is subject to important terms and conditions as set forth in the [LICENSE](LICENSE) file
thing
