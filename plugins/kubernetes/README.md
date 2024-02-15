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

(To opt out of this feature set in pod-template `metadata.annotations.container-nameofcontainer-samson/dockerfile: none`)

For each container (including init containers) Samson finds or creates a matching Docker image for the Git SHA that is being deployed.
Samson always sets the Docker digest, and not a tag, to make deployments immutable.

If `KUBERNETES_ADDITIONAL_CONTAINERS_WITHOUT_DOCKERFILE=true` is set, it will only enforce builds for the first container.

Samson matches builds to containers by looking at the `metadata.annotations.container-nameofcontainer-samson/dockerfile` attribute or the
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

Should be added as a separate role with `metadata.annotations.samson/prerequisite: 'true'` set on the `Job`/`Deployment`/`Pod`
(annotation should be added to the 'root' object, not the `spec.template`).
This role will be deployed/executed before any other role is deployed.
By default it waits for 10 minutes before timeout, change the timeout using
`KUBERNETES_WAIT_FOR_PREREQUISITES` env variable (specified in seconds).

### Deployment timeouts

A deploy will wait for 10 minutes for pods to come alive. You can adjust this
timeout using KUBERNETES_WAIT_FOR_LIVE (specified in seconds).

### Deployment stability check

A deploy will get checked for stability every 2 seconds for a minute, before being marked as stable.
These can be configured (in seconds) using `KUBERNETES_STABILITY_CHECK_DURATION` and `KUBERNETES_STABILITY_CHECK_TICK` environment variables.

### StatefulSet

Prefer `spec.updateStrategy.type=RollingUpdate`

### Server-side apply

Set `metadata.annotations.samson/server_side_apply='true'` and use a valid template.
This only works for kubernetes 1.16+ clusters,
see [kubernetes docs](https://kubernetes.io/docs/reference/using-api/api-concepts/#server-side-apply) for details.

### Duplicate deployments

To deploy the same repository multiple times, create separate projects and then set `metadata.annotations.samson/override_project_label: "true"`,
samson will then override the `project` labels and keep deployments/services unique.

### Updates without overriding

Too keep fields/labels that are managed outside of samson during updates
- for everything set `metadata.annotations.samson/persistent_fields`
- for `Service` also use `KUBERNETES_SERVICE_PERSISTENT_FIELDS`, see .env.example

### PodDisruptionBudget

Samson can add a dynamic PodDisruptionBudget by setting `metadata.annotations.samson/minAvailable: 30%`, it calculates the ceil of this with the configured replicas.
(also supports absolute values like `"1"`)

To remove it, set to '0', deploy, delete it from the template.

Samson can auto-add a `PodDisruptionBudget` for every `Deployment`/`StatefulSet` by setting for example `KUBERNETES_AUTO_MIN_AVAILABLE=80%`.
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

### Resources without namespace

Samson sets namespaces to the deploygroups `kubernetes_namespace` if no `metadata.namespace` is set in the resource.

For namespace-less resources, set `metadata.namespace:` (which will result in `nil`)

### Deployments without replicas

When using a `HorizontalPodAutoscaler` for your `Deployment` or `StatefulSet`, it is recommended to not set `spec.replicas`.

on the `Deployment`
- set `metadata.annotations.samson/NoReplicas: "true"`
- set `metadata.annotations.samson/server_side_apply: "true"`
- do not set `spec.replicas`

### Using custom resource names

When not using project namespaces samson overrides each resource name in a particular role with the resource and service name set in the UI to prevent
collision between resources in the same namespace from different projects unintentionally.

To make Samson leave your resource name alone, set `metadata.annotations.samson/keep_name: 'true'`

### Preventing request loss with preStop

When not using kubernetes services to route requests, requests can be lost during a deployment,
since old pods shut down before everyone all clients are refreshed.

To prevent this, samson can automatically add `container[].lifecycle.preStop` `/bin/sleep <INT>`
and increase the `spec.terminationGracePeriodSeconds` if necessary.

(will only add if `preStop` hook is not set and pod `metadata.annotations.container-nameofcontainer-samson/preStop` is not set to `disabled` and container has ports)

- Set `KUBERNETES_ADD_PRESTOP=true` to enable
- Set `KUBERNETES_PRESTOP_SLEEP_DURATION=30` in seconds to override default sleep duration (3 seconds)

### Showing logs on succeeded deploys

Set `metadata.annoations.samson/show_logs_on_deploy: 'true'` on pods, to see logs when the deploy succeeds.
This can be useful for Migrations (see above).
(On failure, samson always shows all pod logs)

### Changing templates via ENV

For things that need to be different between environments/deploy-groups.

Use an annotation to configure what will to be replaced:
```
metadata.annotations.samson/set_via_env_json: |
  metadata.labels.custom: FOO_ENV_VAR
  metadata.labels.other: BAR_ENV_VAR
```

Then configure an ENV var with that same name and a value that is valid JSON.

 - To set string values as env vars, use quotes, i.e. `"foo"`
 - To set values inside of arrays use numbers as index `spec.containers.0.name`

### Allowing to override static/db env vars

If you want to override or remove env vars like PROJECT,ROLE,TAG ... set this:

`metadata.annotations.container-nameofcontainer-samson/keep_env_var: "TAG,ROLE"`

### Allow randomly not-ready pods during readiness & stability check

Set `KUBERNETES_ALLOW_NOT_READY_PERCENT=20` to allow up to 20% of pods per role being not-ready,
this is useful when dealing with large deployments that have some random failures.

### Allow randomly failing pods during readiness & stability check

Set `KUBERNETES_ALLOW_FAILED_PERCENT=10` to allow up to 10% of pods per role being failed,
this is useful when dealing with large deployments that have some random failures.

### Disabling service selector validation

To debug services or to create resources that needs to reference a selector that doesn't include team/role (like a Gateway), you can disable selector validation with:

`metadata.annotations.samson/service_selector_across_roles: "true"`

### Updating matchLabels

Samson will by default block updating `matchLabels` since it leads to abandoned pods.

If you still want to change a matchLabel, for example project/role:

 - set `metadata.annotations.samson/allow_updating_match_labels: "true"`
 - deploy with renamed project/role
 - manually delete pods from old Deployment (`kubectl delete pods -l project=old-name,role=old-role`)
 - unset annotations from step 1

### Kritis

Allow users to set kritis breakglass per deploy-group or deploy by setting environment variable `KRITIS_BREAKGLASS_SUPPORTED=true`

### Setting environment variables on init containers

Environment variables do not get set on init container by default, but it can be opted in with:
`metadata.annotations.container-nameofcontainer-samson/set_env_vars: "true"`

### Not setting environment variables in sidecars

Environment variables get set on sidecar container by default, but it can be opted out with:
`metadata.annotations.container-nameofcontainer-samson/set_env_vars: "false"`

### Istio sidecar injection via annotation

[Istio](https://istio.io) comes with a Mutating Webhook Admission Controller that will inject an
Envoy proxy sidecar. See Istio's docs on [sidecar injection](https://istio.io/docs/setup/additional-setup/sidecar-injection/)
for more info. The injection is triggered by adding a `sidecar.istio.io/inject: "true"`
annotation on a Pod.

You can configure a Kubernetes Role to tell Samson to inject that annotation to a Pod template
of a Deployment, DaemonSet, or StatefulSet. Assuming you have Istio configured to use the
MutatingWebhook in the target namespace, that should trigger Istio to inject the sidecar.

To enable this functionality, set the environment variable `ISTIO_INJECTION_SUPPORTED=true`.

### Forcing updates when kubernetes cannot change a resource

Delete old resource and create new when an update fails because it `cannot change` a resources.
(Should not be used with `persistentVolumeReclaimPolicy` set to `Delete`)

```
metadata.annotations.samson/force_update: "true"
```

### Forcing a delete-create to get back to a clean state

Delete old resource and create new.
Can be useful for Service migration from NodePort to ClusterIP, or similar scenarios where we want a clean slate.

```
metadata.annotations.samson/recreate: "true"
```

### Static config per deploy group

Set the kubernetes roles to `kubernetes/$deploy_group/server.yml` 

### Ignoring warning events

If a warning event fails deploys, but application owners deem them safe to ignore, add this:

`metadata.annotations.samson/ignore_events="FailedCreate,AnotherEvent"`

... still consider opening a samson PR if the event is universally to be ignored.

### Copying secrets to created namespaces

When using the namespaces UI to create new namespaces, set `KUBERNETES_COPY_SECRETS_TO_NEW_NAMESPACE=my-docker-auth,other-stuff`,
it will then copy that secret from the `default` namespace to any newly created namespace.

### Adding Well-Known Labels

In accordance with [Kubernetes Well-Known Labels](https://kubernetes.io/docs/reference/labels-annotations-taints/#app-kubernetes-io-managed-by),
Samson can set the labels:
- `app.kubernetes.io/managed-by` to `samson`
- `app.kubernetes.io/name` to the project permalink

This feature can be enabled by setting `KUBERNETES_ADD_WELL_KNOWN_LABELS=true`.
