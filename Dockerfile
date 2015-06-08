FROM ruby:2.2.2

RUN apt-get update && apt-get install -y wget apt-transport-https
RUN wget -qO- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN echo 'deb https://deb.nodesource.com/node_0.12 jessie main' > /etc/apt/sources.list.d/nodesource.list
RUN apt-get update && apt-get install -y nodejs

ENV GEM_HOME=/bundle
RUN gem update --system
RUN gem install bundler

RUN mkdir /app
WORKDIR /app

ADD REVISION /REVISION

# Mostly static
ADD config.ru /app/
ADD Rakefile /app/
ADD bin /app/bin
ADD public /app/public
ADD db /app/db
ADD .env.bootstrap /app/.env

# Gems
ADD Gemfile /app/
ADD Gemfile.lock /app/
ADD vendor/cache /app/vendor/cache
ADD package.json /app/package.json

# Plugins need to be added before bundling
# because they're loaded as gems
ADD plugins /app/plugins

RUN npm install

RUN bundle install --without test sqlite postgres --quiet --local --jobs 4 || bundle check

# Code
ADD config /app/config
ADD config/database.docker.yml /app/config/database.yml
ADD app /app/app
ADD lib /app/lib

EXPOSE 9080

CMD DATABASE_URL=$MYSQL_URL bundle exec puma -C ./config/puma.rb
