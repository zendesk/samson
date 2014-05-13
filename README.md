:warning: *Use of this software is subject to important terms and conditions as set forth in the License file* :warning:

## Samson

### What?

A web interface for deployments.

### How?

Samson works by ensuring a git repository for a project is up-to-date, and then executes the commands associated with a stage. If you want to find out exactly what's going on, have a read through the [JobExecution](app/models/job_execution.rb).

Streaming is done through a [controller](app/controllers/streams_controller.rb) that uses [server-sent events](https://en.wikipedia.org/wiki/Server-sent_events) to display to the client.

#### Config

```bash
# Bundle and copy example files into place.
script/bootstrap

# Fill in .env with a few variables
# [REQUIRED]
# SECRET_TOKEN for Rails, can be generated with `bundle exec rake secret`.
# SAMSON_URL (eg. http://localhost:9080)
# GITHUB_ORGANIZATION (eg. zendesk)
# GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET are for GitHub auth
# and can be obtained by creating a new Github Application
# See: https://github.com/settings/applications
# https://developer.github.com/v3/oauth/
# GITHUB_TOKEN is a personal GitHub token. You can generate a new
# at https://github.com/settings/applications - it gets assigned to GITHUB_TOKEN.
#
# [OPTIONAL]
# GITHUB_ADMIN_TEAM (team members automatically become Samson admins)
# GITHUB_DEPLOY_TEAM (team members automatically become Samson deployers)
#
# Authentication is also possible using Zendesk, in that case set your
# Zendesk token to CLIENT_SECRET and your URL to ZENDESK_URL in .env.
# Make one at https://<subdomain>.zendesk.com/agent/#/admin/api -> OAuth clients.
# Set the UID to 'deployment' and the redirect URL to http://localhost:9080/auth/zendesk/callback
#
# You may fill in NEWRELIC_API_KEY using the instructions below if you would
# like a dynamic chart of response time and throughput during deploys.
# https://docs.newrelic.com/docs/features/getting-started-with-the-new-relic-rest-api#setup
```

#### To run

```bash
bundle exec puma -C config/puma.rb
```

The website runs at [http://localhost:9080/](http://localhost:9080) by default.

#### User roles

Role | Description
--- | ---
Viewer | Can view all deploys.
Deployer | Viewer + ability to deploy projects.
Admin | Deployer + can setup and configure projects.
Super Admin | Admin + management of user roles.

The first user that logs into Samson will automatically become a super admin.

#### CI support

Samson can be integrated with CI services through webhooks.
You can find a link to webhook on every project page.
There are links on webhook pages that you will want to add to your project
settings on your CI service.
Set up your webhooks and the deployment process can be automated.

##### Process

-> Push to branch(e.g. master)
-> CI validation
-> CI makes webhook call
-> Samson receives webhook call
-> Samson checks if validation is passed
-> Deploy if passed / do nothing if failed

##### Supported services

* Travis
    * You can add a webhook notification to the .travis.yml file per project
* Semaphore
    * Semaphore has webhook per project settings
    * Add webhook link to your semaphore project
* Tddium
    * Tddium only has webhook per organisation setting
    * However you can have multiple webhooks per organisation
    * Add all webhooks to your organisation
    * Samson will match url to see if the webhook call is for the correct project

Skip a deploy:

Add "[deploy skip]" to your commit message, and Samson will ignore the webhook
from CI.

#### Continuous Delivery & Releases

In addition to automatically deploying passing commits to various stages, you
can also create an automated continuous delivery pipeline. By setting a *release
branch*, each new passing commit on that branch will cause a new release, with a
automatically incrementing version number. The commit will be tagged with the
version number, e.g. `v42`, and the release will appear in Samson.

Any stage can be configured to automatically deploy new releases. For instance,
you might want each new release to be deployed to your staging environment
automatically.

### Contributing

Improvments are always welcome. Please follow the following steps to contribute

1. Submit a Pull Request with a detailed explaination of changes and
screenshots (if UI is changing)
1. Receive a :+1: from a core team member
1. Core team will merge your changes

### Team

Core team is @steved555, @dasch, @jwswj, @halcyonCorsair, @princemaple & @sandlerr.
