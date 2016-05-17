FROM ruby:2.2.3-slim

RUN apt-get update && apt-get install -y wget apt-transport-https git
RUN wget -qO- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN echo 'deb https://deb.nodesource.com/node_0.12 jessie main' > /etc/apt/sources.list.d/nodesource.list
RUN apt-get update && apt-get install -y nodejs build-essential

WORKDIR /app

# Mostly static
ADD config.ru /app/
ADD Rakefile /app/
ADD bin /app/bin
ADD public /app/public
ADD db /app/db
ADD .env.bootstrap /app/.env
ADD .ruby-version /app/.ruby-version

# NPM
ADD package.json /app/package.json
RUN npm install

# Gems
ADD Gemfile /app/
ADD Gemfile.lock /app/
ADD vendor/cache /app/vendor/cache
ADD plugins /app/plugins

RUN apt-get -y install libmysqlclient-dev libpq-dev libsqlite3-dev
RUN bundle install --quiet --local --jobs 4 || bundle check

# Code
ADD config /app/config
ADD app /app/app
ADD lib /app/lib

EXPOSE 9080

CMD ["bundle", "exec", "puma", "-C", "./config/puma.rb"]
