## Zendesk Pusher

### What?

A web interface to Zendesk's deployments.

### How?

It ensures the repository is up-to-date, and then executes the commands associated with that project and stage.

Streaming is done through a [controller](app/controllers/streams_controller.rb) that allows both web access and curl access. A [subscriber thread](config/initializers/instrumentation.rb) is created on startup.

This project used to use JRuby, now it is on MRI 2.0.0, but there is some remnant JRuby code in the codebase. Tests are also run on 2.1.0.

#### Got boxen?

Upgrade your manifest:
```Puppet
include projects::pusher
```

#### Config:

1. We need to add a database configuration yaml file with your credentials. 
2. Set up an authentication method in `.env` - at least one of Zendesk (`CLIENT_SECRET` and `ZENDESK_URL`)and GitHub (`GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`).


```bash
cp config/database.<MS_ACCESS>.yml.example config/database.yml # replace <MS_ACCESS> by your favourite database from mysql, postgres or sqlite
subl config/database.yml # put your credentials in
script/bootstrap

# fill in .env with a couple variables
# [AUTH]
# GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET are for GitHub auth
# and can be obtained by creating a new Github Application
# See: https://github.com/settings/applications
# https://developer.github.com/v3/oauth/
#
# You can currently auth through your Zendesk, in that case set your Zendesk token to CLIENT_SECRET and your URL to ZENDESK_URL in .env.
# Make one at https://<YOU>.zendesk.com/agent/#/admin/api -> OAuth clients. Set the UID to 'deployment' and the redirect URL to http://localhost:9080/auth/zendesk/callback
# [OPTIONAL]
# You also can fill in your personal GitHub token. You can generate a new
# at https://github.com/settings/applications - it gets assigned to GITHUB_TOKEN.
```

#### To run:

```bash
bundle exec puma -C config/puma.rb
```

The website runs at `localhost:9080` by default.

#### Admin user

Once you've successfully logged in via oauth, your first user automatically becomes an admin.

#### Notes

\* Currently `deploy` is hardcoded as the deploy user, you will want
to change it to your own for testing.

[1]: https://github.com/rails/rails/issues/10989

#### CI support

Pusher can be integrated with CI services through webhooks.
You can find a link to webhook on every project page.
There are links on webhook pages that you will want to add to your project settings on your CI service.
Set up your webhooks and the deployment process can be automated.

##### Process

-> Push to branch(e.g. master)  
-> CI validation  
-> CI makes webhook call  
-> Pusher receives webhook call  
-> Pusher checks if validation is passed  
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
    * Pusher will match url to see if the webhook call is for the correct project

### Team

Core team is Steven D (SF), Daniel S (CPH), Jason S (MEL), Elliot P (MEL), Po C (MEL) & Roman S (MEL).
