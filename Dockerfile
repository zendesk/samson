FROM ruby:2.2.1

RUN mkdir /app
WORKDIR /app

# Mostly static
ADD config.ru /app/
ADD Rakefile /app/
ADD bin /app/bin
ADD public /app/public
ADD db /app/db
ADD vendor/assets /app/vendor/assets

# Gems
ADD Gemfile /app/
ADD Gemfile.lock /app/
ADD vendor/cache /app/vendor/cache

# Plugins need to be added before bundling
# because they're loaded as gems
ADD plugins /app/plugins

RUN bundle install --without test sqlite postgres --quiet --local --jobs 4 || bundle check

# Code
ADD config /app/config
ADD app /app/app
ADD lib /app/lib

RUN DATABASE_URL=mysql2://user:pass@127.0.0.1/null RAILS_ENV=development PRECOMPILE=1 bundle exec rake --trace assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "--binding=0.0.0.0"]
