## Zendesk Pusher

### What?

A web interface to Zendesk's deployments.

### How?

[app/jobs/deploy.rb](app/jobs/deploy.rb) holds the heart of the deploy service.
It sshs to admin01\*, changes directory to the parameterized project name (e.g. `CSV Exporter` -> `csv_exporter`),
ensures the repository is up-to-date, and then executes capsu.

Pub-sub streaming is done through redis and a [separate controller](app/controllers/streams_controller.rb) that allows both web access
and curl (TODO) access. A [subscriber thread](config/initializers/redis.rb) is created on startup that handles
writing messages to each individual stream. Since Redis subscription blocks, it is difficult to work with ActionController::Live. [1]

This project makes extensive use of threads, hence the requirement on JRuby.

#### To run:

```bash
script/bootstrap

# fill in .env with a couple variables
# GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET are mandatory
# and can be obtained by creating a new Github Application
# See: https://github.com/settings/applications
# https://developer.github.com/v3/oauth/
#
# You also need to fill in your personal GitHub token. You can generate a new
# at https://github.com/settings/applications - assign it to GITHUB_TOKEN.

bundle exec puma -C config/puma.rb
```

The website runs at `localhost:9080` by default.

#### Admin user

Once you've successfully logged in via oauth, you can make your first user an admin via:

```bash
rails runner 'User.first.update_attribute(:role_id, Role::ADMIN.id)'
```

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
