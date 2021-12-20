# Getting Started

## Server setup

### Option A: Docker

Simple/reproducible but slow to develop on.

```bash
docker-compose up
open http://localhost:3000
```

The local project directory will be mounted into the container, so your changes will be reflected immediately by the server.
When running on virtual the `3000` port forwarding should be configured in virtualbox (Settings -> Network -> Advanced -> Port Forwarding).
When running on virtual `192.168.42.45` use `.env.virtualbox` from `docker-compose.yml`.
When running on neither localhost nor `192.168.42.45` create your own credentials and load them from `docker-compose.yml`.

### Option B: Local machine

Complicated to start, but easy to develop from.

```bash
# install the database you want to use, samson needs mysql, postgresql, or sqlite
sudo apt-get install mysql-dev pg-dev nodejs
brew install postgresql sqlite mysql nodejs

bin/setup # Run the setup script to use the test credentials.
./bin/rails s
open http://localhost:3000
```

### Option C: Heroku

Simple setup, no dependencies, but slow to develop.

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/zendesk/samson)

## Creating the first project
 - Add a new project http://localhost:3000/projects/new
 - name: example-project url: git@github.com:samson-test-org/example-project.git
 - Create a Stage
 - Deploy!

## Permission

Samson assumes the user you are running the service under has permission to perform the various tasks like
cloning repositories. For private repositories especially, this may necessitate uploading SSH keys or keychaining the user/password:
* https://help.github.com/articles/set-up-git/#next-steps-authenticating-with-github-from-git

Otherwise when creating a new project you may get the error "<Repository URL> is not valid or accessible".

## Configuration

### Database

For very small deployments, SQLite is sufficient, however you may want to leverage MySQL or PostgreSQL.
Set up a production block in database.yml with the settings to connect to your DB then run `RAILS_ENV=production bundle exec rake db:setup`

### Webserver

Configure `config/puma.rb` as you need. See [puma's documentation](https://github.com/puma/puma/) for details.
You can start the server using this file by doing `bundle exec puma -C config/puma.rb`.
To restart the server use `kill -USR1 <pid>` which makes it restart without losing any downtime (lost requests).

### Environment variables

Set environment variables in your `.env` file, see `.env.example` for documentation on what is required/available.
Alternatively set them directly in heroku or the process environment.

### Advanced features

For advanced features see the [Extra features page](extra_features.md).

## Production assets

Needs to generate assets before running in production or it will show `not present in the asset pipeline` errors.

`RAILS_ENV=production PRECOMPILE=1 PLUGINS=all bundle exec rake assets:precompile assets:clean[0] --trace`

## Profiling

Generate graphs via [stackprof](https://github.com/tmm1/stackprof) from development console, using the `PROFILE` mode.

```
rake assets:precompile
PROFILE=1 rails c
login User.first
app.get '/' # warmup
flamegraph(name: 'foo') { app.get '/' }
```
