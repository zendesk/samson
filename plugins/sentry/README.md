# Sentry Plugin

Plugin that notifies Sentry of errors. To use it, there is one required environment variable and one optional variable:
Required: [SENTRY_DSN](https://docs.sentry.io/product/sentry-basics/dsn-explainer/)
Optional: [SENTRY_PROJECT](https://github.com/getsentry/sentry-ruby/issues/1786)

### Local testing

- set `SENTRY_DSN` and `SENTRY_PROJECT` in `.env` (see above)
- set `config.environment = 'staging'` in ./config/initializers/sentry.rb
- set `config.consider_all_requests_local = false` in `config/environments/development.rb`
- do not test on 127.0.0.1 (1.1.1.1 / localhost), since that is often filtered out by remote sentry config, but on your local ip
