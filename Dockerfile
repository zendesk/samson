FROM ruby:3.2.4-slim

# Install dependencies
RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential \
    default-libmysqlclient-dev \
    libpq-dev \
    libsqlite3-dev \
    wget \
    apt-transport-https \
    git \
    openssh-client \
    curl \
    gnupg2 \
    nodejs \
    npm && \
  rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://get.docker.com | bash -

WORKDIR /app

# Mostly static
COPY .ruby-version config.ru Rakefile .env.virtualbox ./
COPY bin bin
COPY public public
COPY db db
COPY .env.bootstrap .env

# NPM
COPY package.json ./
RUN npm install --silent >/dev/null

# Gems
COPY Gemfile Gemfile.lock ./
COPY plugins plugins
RUN bundle install --quiet --jobs 4

# Code
COPY config config
COPY app app
COPY lib lib

# Assets
COPY vendor/assets vendor/assets
RUN echo "takes 5 minute" && ./bin/decode_dot_env .env && RAILS_ENV=production PRECOMPILE=1 bundle exec rake assets:precompile 2>/dev/null

EXPOSE 9080

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
