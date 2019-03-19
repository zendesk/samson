# Samson Components

### Projects

A project represents one application and it has a Git repo. A project can be deployed to multiple environments.

### Environments

An environment is deployment environment such as production, staging, testing. An environment can be associated with many Deploy Groups.

### Deploy Groups

Each environment has many deploy groups. A deploy group is a separate group of machines. For example, a deploy group might represent host machines in a region.

Deploy groups are shared by all projects.

### Stages

A Stage deploys a project to many deploy groups and often maps to 1 environment. While deploying an application to production (for example), one might like to roll it out to different deploy groups in certain order (such as from less sensitive to more sensitive), can also be automated with a [pipeline](/plugins/pipelines/README.md).

### Release

A Release represents a build release with a unique release number similar to git tags, such as "v1".

### Builds

A build (such as GCB build) represents a binary (mostly docker image) consisting of a project's checkout at a particular commit along with all required dependencies.

### Deploys

A Deploy refers to deployment of an application to a particular stage. Each deploy can be associated with a build which is being deployed.

### WebHooks

Webhooks trigger a deploy to a stage whenever http request comes in, often used to make a new commit to an associated git branch trigger a deploy.
