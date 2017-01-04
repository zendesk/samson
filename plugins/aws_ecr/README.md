# AWS ECR Plugin

This plugin allows integration between Samson and
[AWS ECR](http://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html),
which is the Docker registry service managed by AWS.

## Overview

AWS ECR requires you to refresh your registry credentials every 12 hours (approximately).
Because Samson only supports to set credentials through the environment, this plugin
runs a callback before every build, requesting AWS for the new credentials. Then sets
these credentials to the environment so the normal docker build process can use them.

It also tries to create a new repository if it does not already exist.

To configure this plugin you need to:

* Enable docker in samson (DOCKER_FEATURE=1)
* Set your ECR registry (DOCKER_REGISTRIES=<account>.dkr.ecr.<aws-region>.amazonaws.com)
* Set your [AWS credentials](http://docs.aws.amazon.com/sdkforruby/api/#Configuration)
* Ensure permissions "ecr:DescribeRepositories" and "ecr:CreateRepository" are available.
