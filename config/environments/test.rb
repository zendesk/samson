Samson::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure static asset server for tests with Cache-Control for performance.
  # We don't need assets in test, so no need to compile/serve them
  config.serve_static_files  = false
  config.assets.compile = false
  config.static_cache_control = "public, max-age=3600"

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # By default, we don't want to actually execute jobs when testing. However,
  # this setting can be enabled on a per-test basis.
  config.samson.enable_job_execution = false

  # We don't want to persist the repository cache between test runs.
  config.samson.cached_repos_dir = Dir.mktmpdir

  config.samson.github.organization = 'test_org'
  config.samson.github.admin_team = 'admins'
  config.samson.github.deploy_team = 'deployers'

  config.active_support.test_order = :random
end

ENV['SECRET_TOKEN'] = 'd6054cf90db212c8fbc070c896c30398e3275532c5602bdf00cb153b806c000e4e46fac2f3acc0783822b8f6d30b5913b6fbcfdd24914553e745b8aa8ddfa5a4'
ENV['DEFAULT_URL'] = 'http://www.test-url.com'
ENV['DATADOG_API_KEY'] = 'dapikey'
ENV['DATADOG_APPLICATION_KEY'] = 'dappkey'
ENV['JENKINS_URL']='http://www.test-url.com'
ENV['JENKINS_USERNAME']='user@test.com'
ENV['JENKINS_API_KEY']='japikey'
