# frozen_string_literal: true
source 'https://rubygems.org'

ruby File.read('.ruby-version').strip

# gems that have rails engines are are always needed
group :preload do
  gem 'rails', '5.1.0'
  gem 'dotenv'
  gem 'sse-rails-engine'
  gem 'connection_pool'
  gem 'marco-polo'

  # AR extensions
  gem 'goldiloader'
  gem 'kaminari'
  gem 'audited'
  gem 'soft_deletion'
  gem 'doorkeeper'
end

gem 'bundler'
gem 'dogstatsd-ruby'
gem 'puma'
gem 'attr_encrypted'
gem 'sawyer'
gem 'dalli'
gem 'omniauth'
gem 'omniauth-oauth2'
gem 'omniauth-github'
gem 'omniauth-google-oauth2'
gem 'omniauth-ldap'
gem 'omniauth-gitlab'
gem 'omniauth-bitbucket'
gem 'octokit'
gem 'faraday'
gem 'faraday-http-cache'
gem 'warden'
gem 'active_hash'
gem 'ansible'
gem 'github-markdown'
gem 'coderay'
gem 'net-http-persistent'
gem 'concurrent-ruby'
gem 'vault'
gem 'docker-api'
gem 'newrelic_rpm'
gem 'ddtrace' # datadog APM
gem 'lograge'
gem 'logstash-event'
gem 'diffy'
gem 'validates_lengths_from_database'

# treat included plugins like gems
Dir[File.join(Bundler.root, 'plugins/*/')].each { |f| gemspec path: f }

group :mysql2 do
  gem 'mysql2'
end

group :postgres do
  gem 'pg'
end

group :sqlite do
  gem "sqlite3"
end

group :production, :staging do
  gem 'airbrake'
  gem 'airbrake-user_informer'
end

group :assets do
  gem 'ngannotate-rails'
  gem 'sass-rails'
  gem 'uglifier'
  gem 'bootstrap-sass'

  source 'https://rails-assets.org' do
    gem 'rails-assets-angular'
    gem 'rails-assets-angular-mocks'
    gem 'rails-assets-angular-scenario'
    gem 'rails-assets-bootstrap-select'
    gem 'rails-assets-jquery'
    gem 'rails-assets-jquery-ui'
    gem 'rails-assets-jquery-ujs'
    gem 'rails-assets-moment'
    gem 'rails-assets-typeahead.js'
    gem 'rails-assets-underscore'
    gem 'rails-assets-x-editable'
    gem 'rails-assets-jstimezonedetect'
    gem 'rails-assets-jquery-cookie'
  end
end

group :development, :staging do
  gem 'rack-mini-profiler'
end

group :development, :test do
  gem 'byebug'
  gem 'bootsnap'
  gem 'pry-rails'
  gem 'pry'
  gem 'awesome_print'
  gem 'brakeman'
  gem 'rubocop'
  gem 'flay'
  gem 'parallel_tests'
  gem 'forking_test_runner'
end

group :test do
  gem 'minitest-rails'
  gem 'rails-controller-testing'
  gem 'maxitest'
  gem 'mocha'
  gem 'webmock'
  gem 'single_cov'
  gem 'ar_multi_threaded_transactional_tests'
  gem 'bundler-audit', require: false
end
