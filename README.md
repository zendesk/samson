**Use of this software is subject to important terms and conditions as set forth in the License file**

## Samson

[![Build Status](https://travis-ci.org/zendesk/samson.svg?branch=master)](https://travis-ci.org/zendesk/samson)

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
* Ruby (currently 2.1.1)

#### Setup

Run the bootstrap script to use the test credentials.

```bash
script/bootstrap
rails s
open http://localhost:3000
```

 - Add a new project http://localhost:3000/projects/new
 - name: example-project url: git@github.com:samson-test-org/example-project.git
 - Create a Stage
 - Deploy!

For a real setup:

#### Database

Set up a production block in database.yml with the settings to connect to your DB then run `RAILS_ENV=production bundle exec rake db:setup`

#### Webserver

Configure `config/puma.rb` as you need. See [puma's documentation](https://github.com/puma/puma/) for details. You can start the server using this file by doing `puma -C config/puma.rb`.

#### Environment

Set the following config in your `.env` file:

##### General app (mandatory)

*SECRET_TOKEN* for Rails, generated during script/bootstrap.

##### GitHub token (mandatory)

*GITHUB_TOKEN*

This is a personal access token that Samson uses to access project repositories, commits, files and pull requests.

* Navigate to [https://github.com/settings/tokens/new](https://github.com/settings/tokens/new) to generate a new personal access token
* Choose scope including repo, read:org, user and then generate the token
* You should now have a personal access token to populate the .env file with

##### GitHub OAuth (mandatory)

*GITHUB_CLIENT_ID* and *GITHUB_SECRET*

* Navigate to [https://github.com/settings/applications/new](https://github.com/settings/applications/new) and register a new OAuth application
* Set the Homepage URL to http://localhost:3000
* Set the Authorization callback URL to http://localhost:3000/auth/github/callback
* You should now have Client ID and Client Secret values to populate the .env file with

##### General app (optional)

*DEFAULT_URL* absolute url to samson (used by the mailer), e.g. http://localhost:3000

##### GitHub organisation and teams (optional)

Samson can use an organisation's teams to provide default roles to users authenticating with GitHub.

*GITHUB_ORGANIZATION* name of the organisation to read teams from, e.g. zendesk

*GITHUB_ADMIN_TEAM* members of this team automatically become Samson admins, e.g. owners

*GITHUB_DEPLOY_TEAM* members of this team automatically become Samson deployers, e.g. deployers

##### GitHub URLs (optional)

Samson can use custom GitHub endpoints if, for example, you are using GitHub enterprise.

*GITHUB_WEB_URL* used for GitHub interface links, e.g. compare screens, OAuth authorization

*GITHUB_API_URL* used for GitHub API access

##### Google OAuth (optional)

*GOOGLE_CLIENT_ID* and *GOOGLE_CLIENT_SECRET*

* Navigate to https://console.developers.google.com/project and create a new project
* Enter a name and a unique project id
* Once the project is provisioned, click APIs & auth
* Turn on Contacts API and Google+ API (they are needed by Samson to get email and avatar)
* Click the Credentials link and then create a new Client ID
* Set the Authorized JavaScript Origins to http://localhost:3000
* Set the Authorized Redirect URI to http://localhost:3000/auth/google/callback
* Create the Client ID
* You should now have Client ID and Client secret values to populate the .env file with

##### New Relic integration (optional)

*NEWRELIC_API_KEY*

You may fill in using the instructions below if you would
like a dynamic chart of response time and throughput during deploys.
[https://docs.newrelic.com/docs/features/getting-started-with-the-new-relic-rest-api#setup](https://docs.newrelic.com/docs/features/getting-started-with-the-new-relic-rest-api#setup)

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
* Jenkins
    * Setup using the [Notification Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Notification+Plugin)
* Buildkite
    * You can add a webhook per project under settings/notifications
    * You can add any value to the 'Token' field, as it is not used
* Github
    * You may add a webhook for push events

Skip a deploy:

Add "[deploy skip]" to your commit message, and Samson will ignore the webhook
from CI.

##### Other

* JIRA
* Datadog
* New Relic
* Flowdock
* Slack
* Github

#### Continuous Delivery & Releases

In addition to automatically deploying passing commits to various stages, you
can also create an automated continuous delivery pipeline. By setting a *release
branch*, each new passing commit on that branch will cause a new release, with a
automatically incrementing version number. The commit will be tagged with the
version number, e.g. `v42`, and the release will appear in Samson.

Any stage can be configured to automatically deploy new releases. For instance,
you might want each new release to be deployed to your staging environment
automatically.

### Instrumentation

Samson sends StatsD basic web request metrics and metrics about deploys and threads
in use. Statsd silently disables itself if no agent is running on the host. All
metrics collected are prepending with 'samson.app'.

### Contributing

Improvements are always welcome. Please follow these steps to contribute

1. Submit a Pull Request with a detailed explaination of changes and
screenshots (if UI is changing)
1. Receive a :+1: from a core team member
1. Core team will merge your changes

### Team

Core team is [@steved](https://github.com/steved), [@dasch](https://github.com/dasch), [@jwswj](https://github.com/jwswj), [@halcyonCorsair](https://github.com/halcyonCorsair), [@princemaple](https://github.com/princemaple), [@bolddane](https://github.com/bolddane), [@pswadi-zendesk](https://github.com/pswadi-zendesk).
