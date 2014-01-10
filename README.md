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
# CLIENT_SECRET is mandatory and is the secret of a "deployment" OAuth client
# The callback for the OAuth client is {HOST}/auth/zendesk/callback
# ZENDESK_URL defaults to "http://dev.localhost", but is used for authorization
# An example Zendesk OAuth Client config - http://cl.ly/image/47282r002n02

bundle exec puma -C config/puma.rb -p 9080
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
