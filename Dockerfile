FROM ruby:2.2.4-alpine

# install packages and clear the cache after
# - nodejs for precompile and runtime asset compilation
# - ca-certificates so we can do ssl
# - git because we run checkouts
# - nokogiri requirements
# - binaries for all the databases we support
RUN apk add --update \
  nodejs \
  git \
  ca-certificates \
  build-base \
  libxml2-dev \
  libxslt-dev \
  postgresql-dev \
  sqlite-dev \
  mysql-dev && \
  rm -rf /var/cache/apk/*

# bundler does not want to install as root
RUN bundle config --global silence_root_warning 1

# Use system packages to building nokogiri
RUN bundle config build.nokogiri --use-system-libraries

WORKDIR /app

# Mostly static
ADD config.ru /app/
ADD Rakefile /app/
ADD bin /app/bin
ADD public /app/public
ADD db /app/db
ADD .env.bootstrap /app/.env
RUN echo '2.2.4' > /app/.ruby-version

# NPM
ADD package.json /app/package.json
RUN npm install

# Gems
ADD Gemfile /app/
ADD Gemfile.lock /app/
ADD vendor/cache /app/vendor/cache
ADD plugins /app/plugins

RUN bundle install --quiet --local --jobs 4 || bundle check

# Code
ADD config /app/config
ADD app /app/app
ADD lib /app/lib

EXPOSE 9080

CMD ["bundle", "exec", "puma", "-C", "./config/puma.rb"]
