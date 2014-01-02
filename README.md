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
# Make sure you have JRuby installed
bundle install

cp .env.example .env

# fill in .env with a couple variables
# CLIENT_SECRET is mandatory and is the secret of a "deployment" OAuth client.
# The callback for the OAuth client is {HOST}/auth/zendesk/callback
# ZENDESK_URL defaults to "http://dev.localhost", but is used for authorization

ln -s config/database.mysql.yml.exmple config/database.yml
ln -s config/redis.yml.exmple config/redis.yml
ln -s config/redis.development.conf.example config/redis.development.conf

bundle exec rake db:setup

foreman start
```

#### Admin user

Once you've successfully logged in via oauth, you can make your first user an admin via:

```bash
rails runner 'User.first.update_attribute(:role, 2)'
```


The website runs at `localhost:8080` by default.

\* Currently `deploy` is hardcoded as the deploy user, you will want
to change it to your own for testing.

[1]: https://github.com/rails/rails/issues/10989
