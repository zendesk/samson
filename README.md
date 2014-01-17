## Zendesk Pusher

### What?

A web interface to Zendesk's deployments.

### How?

It sshs to admin01\*, changes directory to the parameterized project name (e.g. `CSV Exporter` -> `csv_exporter`),
ensures the repository is up-to-date, and then executes capsu.

Streaming is done through a [controller](app/controllers/streams_controller.rb) that allows both web access and curl access. A [subscriber thread](config/initializers/instrumentation.rb) is created on startup.

This project used to use JRuby, now it is on MRI 2.0.0, but there is some remnant JRuby code in the codebase. Tests are also run on 2.1.0.

#### Got boxen?

Upgrade your manifest:
```Puppet
include projects::pusher
```

#### Config:

```bash
script/bootstrap

# fill in .env with a couple variables
# GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET are mandatory for production
# and can be obtained by creating a new Github Application
# See: https://github.com/settings/applications
# https://developer.github.com/v3/oauth/
#
# You also need to fill in your personal GitHub token. You can generate a new
# at https://github.com/settings/applications - it gets assigned to GITHUB_TOKEN.
# You can currently auth through your Zendesk, in that case your Zendesk token gets set to CLIENT_SECRET. Make one at https://<YOU>.zendesk.com/agent/#/admin/api -> OAuth clients. Set the UID to 'deployment' and the redirect URL to http://localhost:9080/auth/zendesk/callback
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

`start`  
-> push to branch(e.g. master)  
-> CI validation  
-> CI makes webhook call  
-> Pusher receives webhook call  
-> Pusher checks if validation is passed  
-> deploy if passed / do nothing if failed  
`end`  

* Travis
    * TBA
* Semaphore
    * Semaphore has webhook per project settings
    * add webhook link to your semaphore project
* Tddium
    * Tddium only has webhook per organisation setting
    * However you can have multiple webhooks per organisation
    * add all webhooks to your organisation
    * Pusher will match url to see if the webhook call is for the correct project
