# Kubernetes Plugin

Allows Samson to be able to deploy to [Kubernetes](kubernetes.io), and includes various validations and dashboards.

## Overview

Samson will talk to N Kubernetes clusters via their API.
Clusters can be running locally (Docker For Mac / Minikube), in a datacenter,
on EKS, or GKE.

Workflow:
1. Enable the Docker feature by adding `DOCKER_FEATURE=1` to your `.env` file
1. Enable the [Deploy Group](/docs/extra_features.md) feature by adding `DEPLOY_GROUP_FEATURE=1` to your `.env` file
1. Configure Kubernetes cluster(s) on `/kubernetes/clusters`
1. Create a project containing a `Dockerfile`
1. Add [Kubernetes role files](#kubernetes-roles) to your project repository
1. Configure "Roles" for the project `/projects/<PROJECT>/kubernetes/roles`
1. Create a stage that's connected to N deploy groups
1. Configure how many replicas, CPU, and memory each deploy group should use
1. Click 'Deploy' 🎉

## Configuring the Cluster

Use Samson cluster UI (`/kubernetes/clusters`) to configure where the [kubeconfig file](http://kubernetes.io/v1.0/docs/user-guide/kubeconfig-file.html)
for your cluster is and what context (custer/user pair) to use. You need to be a Super Admin to create a cluster.

### Mapping DeployGroups to Clusters

In the "Edit Deploy Group" UI `/deploy_groups`, select a Kubernetes cluster and a namespace.

Background:
Kubernetes has the concept of a [Namespace](http://kubernetes.io/v1.0/docs/user-guide/namespaces.html),
which means a virtual cluster inside of a single physical cluster. This can be
useful if you want to have a single Kubernetes cluster running in AWS or a
datacenter, but logically divide them between a "staging" and "production"
namespace.

## Project Configuration

Project pages will have a Kubernetes link (white wheel on a blue background).

### Kubernetes Roles

A "role" is not a concept in Kubernetes itself. It is specific to Samson.

It refers to the different ways that a project can be run, that may want to
be scaled separately. For each role, Samson allows configuring CPU (requests and limits),
memory (requests and limits), and replicas per deploy group.

Each time this project is deployed, it deploys all roles.

For example, a Ruby on Rails project that uses Resque for background
job processing. This project will likely have 4 roles:

1. The "Migration" role that runs database migrations, 1 replica, low cpu
1. The "App Server" role, that runs the Rails server, 3 replicas, high cpu
1. The "Resque Worker" role, that runs instances of the workers, 5 replicas, high cpu
1. The "Resque Scheduler" role, a singleton process that manages recurring jobs, 1 replica, low cpu

### Configuration Files

Each [Kubernetes role](#kubernetes-roles) is read from a file in the project's repository
. It has to contain the definitions of N Deployment/Daemonset/Service/Job/ConfigMap/etc. Samson's `TemplateFiller`
then augments the definitions by adding docker repo digest, labels, annotations, resource limits,
environment variables, secrets, etc and then sends them to the Kubernetes API.

Multiple roles will likely be similar, but have different commands or liveness probes.
([kucodiff](https://github.com/grosser/kucodiff) can be used to make sure they stay in sync).

Validate required environment variables are set by adding `metadata.annotations.samson/required_env`
to the pod definition with a space separated list of variable names.

```
samson/required_env: >
  RAILS_ENV
  OTHER_STUFF

```

### Limits

Samson allows limiting how many resources each project can use per Deploy Group, see `/kubernetes/usage_limits`.

To forbid deployment of anything without a limit, add a `All/All` limit with 0 cpu and memory.

To allow creating limits without scoped or project, set `KUBERNETES_ALLOW_WILDCARD_LIMITS=true`.

## Deploying to Kubernetes

Each deploy selects a Git SHA and N deploy groups to deploy to. For this Git SHA Samson finds or creates all builds that
were requested in the [Kubernetes role config files](#configuration-files).

### Record Keeping

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

### Docker Images

(To opt out of this feature set `containers[].samson/dockerfile: none` or `metadata.annotations.container-nameofcontainer-samson/dockerfile: none`)

For each container (including init containers) Samson finds or creates a matching Docker image for the Git SHA that is being deployed.
Samson always sets the Docker digest, and not a tag, to make deployments immutable.

If `KUBERNETES_ADDITIONAL_CONTAINERS_WITHOUT_DOCKERFILE=true` is set, it will only enforce this for the first container.

Samson matches builds to containers by looking at the `containers[].samson/dockerfile` attribute or the
base image name (part after the last `/`), if the project has enabled `Docker images built externally`.

Images can be built locally via `docker build`, or via `gcloud` CLI (see Gcloud plugin), or externally and then sent to Samson via the
API (`POST /builds.json`).

### Injected config

Via [Template filler](/plugins/kubernetes/app/models/kubernetes/template_filler.rb)

 - Docker image
 - Limits + replicas
 - Environment variables: POD_NAME, POD_NAMESPACE, POD_IP, REVISION, TAG, DEPLOY_ID, DEPLOY_GROUP, PROJECT, ROLE,
   KUBERNETES_CLUSTER_NAME, and environment variables defined via [env](/plugins/env) plugin.
 - Secret puller and secret annotations (if secret puller + vault is used)

### Migrations / Prerequisite

Add a role with only a `Pod`, `metadata.annotations.samson/prerequisite: 'true'`, and command to run a migrations.
It will be executed before the rest is deployed.

For default it waits for 10 minutes before timeout, you can change the timeout
using KUBERNETES_WAIT_FOR_PREREQUISITES env variable (specified in seconds).

### Deployment timeouts

A deploy will wait for 10 minutes for pods to come alive. You can adjust this
timeout using KUBERNETES_WAIT_FOR_LIVE (specified in seconds).

### Deployment stability check

A deploy will get checked for stability every 2 seconds for a minute, before being marked as stable.
These can be configured (in seconds) using `KUBERNETES_STABILITY_CHECK_DURATION` and `KUBERNETES_STABILITY_CHECK_TICK` environment variables.

### StatefulSet

On kubernetes <1.7 they can only be updated with `OnDelete` updateStrategy,
which is supported by updating only the pod containers and replica count (not set metadata/annotations).
Prefer `RollingUpdate` if possible instead.

### Duplicate deployments

To deploy the same repository multiple times, create separate projects and then set `metadata.annotations.samson/override_project_label: "true"`,
samson will then override the `project` labels and keep deployments/services unique.

### Service updates

Too keep fields/labels that are manually managed persistent during updates, use `KUBERNETES_SERVICE_PERSISTENT_FIELDS`, see .env.example
or set `metadata.annotations.samson/persistent_fields`

### PodDisruptionBudget

Samson can add a dynamic PodDisruptionBudget by setting `metadata.annotations.samson/minAvailable: 30%`, it calculates the ceil of this with the configured replicas.
(also supports absolute values like `"1"`)

To remove it, set to '0', deploy, delete it from the template.

Samson can auto-add a `PodDisruptionBudget` for every `Deployment` by setting for example `KUBERNETES_AUTO_MIN_AVAILABLE=80%`.
Users can opt-out by setting `metadata.annotations.samson/minAvailable: disabled`.

### Blue/Green Deployment

Can be enabled per role, it then starts a new isolated deployment shifting between blue and green sufixes,
switching service selectors if successfully deployed and deleting previous resources.
All active resources must be deleted manually when switching to blue/green from regular deployment.

### Resources without cpu limits

Set `KUBERNETES_NO_CPU_LIMIT_ALLOWED=1`, see [#2820](https://github.com/zendesk/samson/issues/2820) for why this can be useful.

### Enforcing team ownership

Knowing which team owns each component is useful, set `KUBERNETES_ENFORCE_TEAMS=true`
to make all kubernetes deploys that do not use a `metadata.labels.team` / `spec.template.metadata.labels.team` fail.

### Using custom namespace

Samson overrides each resources namespace with to the deploygroups `kubernetes_namespace`.

To make Samson not override the namespace, set `metadata.annotations.samson/keep_namespace: 'true'`
(or `metadata.labels.kubernetes.io/cluster-service: 'true'`)

### Using custom resource names

Samson overrides each resource name in a particular role with the resource and service name set in the UI to prevent
collision between resources in the same namespace from different projects unintentionally.

To make Samson leave your resource name alone, set `metadata.annotations.samson/keep_name: 'true'`

### Preventing request loss with preStop

To enable the following functionality you need to set `KUBERNETES_ADD_PRESTOP=true`.

Samson automatically adds `container[].lifecycle.preStop` `sleep 3` if a preStop hook is not set and
`container[].samson/preStop` is not set to `disabled`, to prevent in-flight requests from getting lost when taking a pod
out of rotation (alternatively set `metadata.annoations.container-nameofcontainer-samson/preStop: disabled`).

### Showing logs on successful deploys

Set `metadata.annoations.samson/show_logs_on_deploy: 'true'` on pods, to see logs when the deploy succeeds.
This can be useful for Migrations (see above).
(On failure, samson always shows all pod logs)

### Changing templates via ENV

For custom things that need to be different between environments/deploy-groups.

Use an annotation to configure what will to be replaced:
```
metadata.annotations.samson/set_via_env_json-metadata.labels.custom: SOME_ENV_VAR
```
Then configure an ENV var with that same name and a value that is valid JSON.

### Allow randomly not-ready pods during redines check

Set `KUBERNETES_ALLOW_NOT_READY_PERCENT=10` to allow up to 10% of pods being not-ready,
this is useful when dealing with large deployments that have some random failures.

### Disabling service selector validation

To debug services or to create resources that needs to reference a selector that doesn't include team/role (like a Gateway), you can disable selector validation with:

`metadata.annotations.samson/service_selector_across_roles: "true"`
