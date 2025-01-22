# frozen_string_literal: true

require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Turn false under Spring and add config.action_view.cache_template_loading = true.
  config.cache_classes = true

  # Eager loading loads your whole application. When running a single test locally,
  # this probably isn't necessary. It's a good idea to do in a continuous integration
  # system, or in some way before deploying your code.
  config.eager_load = !!ENV['EAGER_LOAD']

  # Configure public file server for tests with Cache-Control for performance.
  # We don't need assets in test, so no need to compile/serve them
  config.public_file_server.enabled = false
  config.assets.compile = !!ENV['PRECOMPILE']
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  # config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # We don't want to persist the repository cache between test runs.
  config.samson.cached_repos_dir = Dir.mktmpdir

  config.samson.github.organization = 'test_org'
  config.samson.github.admin_team = 'admins'
  config.samson.github.deploy_team = 'deployers'

  config.active_support.test_order = :random
end

# make our tests fast by avoiding asset compilation
# but do not raise when assets are not compiled either
Rails.application.config.assets.compile = false
Sprockets::Rails::Helper.prepend(
  Module.new do
    def resolve_asset_path(path, *)
      super || path
    end
  end
)
