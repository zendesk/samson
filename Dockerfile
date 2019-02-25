FROM ruby:2.5.3-slim AS base

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      libpq-dev \
      libsqlite3-dev \
      wget \
      apt-transport-https \
      git \
      curl \
      gnupg2 \
  && curl -sL https://deb.nodesource.com/setup_6.x | bash - \
  && apt-get install nodejs -y \
  && curl -fsSL https://get.docker.com | bash - \
  && wget -qc https://github.com/betalo-sweden/await/releases/download/v0.4.0/await-linux-amd64 \
  && install await-linux-amd64 /usr/local/bin/await \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# -------------------------------------
FROM base AS bundle

COPY .ruby-version Gemfile Gemfile.lock /app/
COPY plugins /app/plugins
RUN bundle install --jobs 4

# -------------------------------------
FROM base as node_modules

COPY package.json /app/package.json
RUN npm install --silent

# -------------------------------------
FROM base AS samson

# Drop privs to samson user as some tests expect non-root
RUN groupadd -r samson && useradd -r -g samson -d /app samson \
  && chown -R samson:samson /app

# Copy rubygem and npm results from other stages
COPY --from=bundle /usr/local/bundle /usr/local/bundle
COPY --chown=samson:samson --from=node_modules /app/node_modules /app/node_modules

USER samson

# Copy source code
COPY --chown=samson:samson . /app/
COPY --chown=samson:samson .env.bootstrap /app/.env
RUN ./bin/decode_dot_env .env

# -------------------------------------
FROM samson AS samson-test

ARG RAILS_ENV=development
RUN bundle exec rake assets:precompile

# -------------------------------------
FROM samson AS samson-puma

ARG RAILS_ENV=production
ARG PRECOMPILE=1
RUN bundle exec rake assets:precompile

EXPOSE 9080

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
