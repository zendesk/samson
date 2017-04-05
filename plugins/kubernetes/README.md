# Kubernetes Plugin

This plugin allows integration between Samson and [Kubernetes](kubernetes.io),
an orchestration framework for Docker images.

### Warning: Plugin Incomplete

**The Kubernetes plugin is still under active development, and not feature
complete. Be aware that the code may change, and there is still functionality
pending.**

## Overview

The plugin works by communicating with one or more Kubernetes clusters via
their APIs. It uses a ruby gem called [kubeclient](https://github.com/abonas/kubeclient).
It is possible for Samson to communicate with multiple clusters, e.g. one
cluster running locally on your laptop, a second cluster running in an AWS
environment, and a third in a remote datacenter.  See the section below on
configuring clusters.

Once you have connected to one or more clusters, you can configure a project
to deploy it to Kubernetes. That involves:

1. Set up your project so you can create Builds with Docker images
2. Configuring one or more "Roles" for the project
3. Creating one or more Kubernetes configuration files in the project

Once all those are in place, you can use the Samson UI to deploy a project
Build to one or more Kubernetes clusters.

## Configuring the Cluster

Kubernetes has a concept called the [kubeconfig file](http://kubernetes.io/v1.0/docs/user-guide/kubeconfig-file.html).
That contains information about the clusters available, and the user
credentials used to authenticate with them. Samson has the ability to read
those files and use them to connect to the Kubernetes clusters.

In Samson, if you are logged in as a super-admin, you can access the
Admin -> Kubernetes page. This page allows you to define or edit clusters
by entering the path of a kubeconfig file, and specifying which "context"
(which means a cluster/user pair) you wish to use in that file.

At the moment, there is no way to modify that file or enter data through
the Samson UI.

### Mapping DeployGroups to Clusters

Kubernetes has the concept of a [Namespace](http://kubernetes.io/v1.0/docs/user-guide/namespaces.html),
which means a virtual cluster inside of a single physical cluster. This can be
useful if you want to have a single Kubernetes cluster running in AWS or a
datacenter, but logically divide them between a "staging" and "production"
namespace.

To represent this, there is the ability to map a DeployGroup to a Kubernetes
cluster, and specify a Namespace. In the "Edit Deploy Group" UI, you can
choose from a drop-down of available Kubernetes Clusters, and type in the
namespace.

## Project Configuration

In order to deploy a project with Kubernetes, you'll need to do a little work
to configure it.

If you have the Kubernetes plugin enabled, on the Project page you will see
a tab with the Kubernetes icon, that looks like a white wheel on a blue
background.

### Kubernetes Roles

A "role" is not a concept in Kubernetes itself. It is specific to Samson.

It refers to the different ways that a project can be run, that may want to
be scaled separately. This works best as an example.

Let's say we have a Ruby on Rails project that uses Resque for background
job processing. This project will likely have 3 roles:

1. The "App Server" role, which would run the Rails server
2. The "Resque Worker" role, which would be an instance of the workers
3. The "Resque Scheduler" role, a singleton process that manages recurring jobs

When you deploy this project, you will likely want to be able to scale those
3 aspects separately. You might have 5 instances of the app server running,
but only 3 instances of the workers, and 1 of the scheduler. Each time this project
is deployed, it actually deploys all 3 roles of this project. So they need to
be represented separately.

If you click the Kubernetes icon on the Project page, you will see a UI that
lists the Roles defined, and allows you to add or edit them. Each role
requires:

* its own config file (see below)
* the amount of RAM required
* the fractional number of CPUs it will use
* the default number of replicas to deploy

### Configuration Files

To deploy to Kubernetes, Samson reads in configuration file from the project
repository. That file is expected to contain the definition of a Deployment/Daemonset/Service/Job/etc.
Samson will read in that file from the project repository, make some
changes (like updating the Docker image and adding labels), and send that
to the Kubernetes API.

Each role is expected to have its own configuration file. The contents of
the files will likely be similar for each role, though it will likely
have a different command or liveness probe
([kucodiff](https://github.com/grosser/kucodiff) can be used to make sure they stay in sync).

Environment variables with `value: filled-by-samson` are verified to be filled out, use `env` plugin to configure them.

## Deploying to Kubernetes

When it comes time to deploy to Kubernetes, you can use the UI to specify
which `Build` of the project you want to deploy, and to which `DeployGroups`.
You can also specify the number of replicas you want to deploy for each role,
which will default to the values set in the role configuration.

### Objects Created

For each deploy, a `Kubernetes::Release` is created, which tracks which `Build` was deployed and
who executed it.

For each `DeployGroup` and `Kubernetes::Role` in the deploy, a `Kubernetes::ReleaseDoc` is created, which tracks what kubernetes
configuration was used.

```
Kubernetes::Release
  |
   -> Kubernetes::ReleaseDoc (1 per role and DeployGroup)
      |
      -> Kubernetes Pods (how ever many replicas specified)
```

### Injected config

Via [Template filler](/plugins/kubernetes/app/models/kubernetes/template_filler.rb)

 - docker image if samson built it
 - limits + replicas
 - environment variables: POD_NAME, POD_NAMESPACE, POD_IP, REVISION, TAG, DEPLOY_ID, DEPLOY_GROUP, PROJECT, ROLE,
   KUBERNETES_CLUSTER_NAME, and environment variables defined via [env](/plugins/env) plugin.
 - secret puller and secret annotations (if secret puller + vault is used)

### Migrations

Add a role with only a `Pod`, the annotation `samson/prerequisite: true`, and command to run a migrations.
It will be executed before the rest is deployed.

### Clair security scans

To security scan docker images using hyperclair, enable hyperclair plugin and add:

```
HYPERCLAIR_PATH=/filesystem/path/to/hyperclair
```

Must exit with 0 for success and 1 for failure.
