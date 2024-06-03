# frozen_string_literal: true
source 'https://rubygems.org'

ruby File.read('.ruby-version').strip

# gems that have rails engines are are always needed
group :preload do
  rails_version = '~> 6.1.7'
  gem 'railties', rails_version
  gem 'actioncable', rails_version
  gem 'actionmailer', rails_version
  gem 'activerecord', rails_version

  gem 'dotenv'
  gem 'connection_pool'
  gem 'marco-polo' # TODO: https://github.com/arches/marco-polo/pull/16

  # AR extensions
  gem 'goldiloader'
  gem 'pagy'
  gem 'audited'
  gem 'soft_deletion'
  gem 'doorkeeper', '~>5.6.0'
  gem 'mail', '~> 2.7.0' # TODO: upgrade breaks `rails c`
end

gem 'dogstatsd-ruby'
gem 'puma', '~>5.6.7'
gem 'attr_encrypted'
gem 'sawyer'
gem 'dalli'
gem 'oauth2', '~>2.0.9'
gem 'omniauth', '~>2.0'
gem 'omniauth-oauth2'
gem 'omniauth-github', git: "https://github.com/omniauth/omniauth-github.git" # needs >1.3.0
gem 'omniauth-google-oauth2'
gem 'omniauth-ldap',
  git: 'https://github.com/omniauth/omniauth-ldap.git',
  ref: 'fb485bb4613074b224b8d6b28ad1c7f366a6b6d8'
gem 'omniauth-gitlab'
gem 'omniauth-atlassian-bitbucket'
gem 'omniauth-rails_csrf_protection' # remove once https://github.com/omniauth/omniauth/pull/809 is resolved
gem 'octokit'
gem 'faraday', '~> 2.7'
gem 'faraday-net_http_persistent', '~> 2.0'
gem 'faraday-http-cache'
gem 'faraday-retry'
gem 'warden'
gem 'active_hash'
gem 'ansible'
gem 'commonmarker'
gem 'coderay'
gem 'net-http-persistent'
gem 'concurrent-ruby'
# Can delete once this PR https://github.com/hashicorp/vault-ruby/pull/188 is merged and changes reconciled
gem 'vault', git: 'https://github.com/zendesk/vault-ruby.git', ref: '96be391a2fd50a42871c8b9dc3c59fddbdbdc556'
gem 'lograge'
gem 'logstash-event'
gem 'hashdiff', git: 'https://github.com/liufengyun/hashdiff.git' # fails to install on ruby 3.2 from gem when deploying
gem 'diffy'
gem 'validates_lengths_from_database'
gem 'large_object_store'
gem 'parallel'
gem 'stackprof'
gem 'net-smtp'
gem 'net-pop'
gem 'net-imap'

# treat included plugins like gems
Dir[File.join(Bundler.root, 'plugins/*/')].each { |f| gemspec path: f }

group :mysql do
  gem 'mysql2'
end

group :postgres do
  gem 'pg'
end

group :sqlite do
  gem "sqlite3"
end

group :assets do
  gem 'sprockets-rails'
  gem 'sprockets', '~> 3.7'
  gem 'sass-rails'
  gem 'uglifier'
  gem 'bootstrap-sass', '>= 3.4.1'
  gem 'momentjs-rails'
  gem 'bootstrap3-datetimepicker-rails'

  source 'https://rails-assets.org' do
    gem 'rails-assets-bootstrap-select'
    gem 'rails-assets-jquery'
    gem 'rails-assets-jquery-ui'
    gem 'rails-assets-jquery-ujs'
    gem 'rails-assets-typeahead.js'
    gem 'rails-assets-underscore'
    gem 'rails-assets-x-editable'
    gem 'rails-assets-jstimezonedetect'
    gem 'rails-assets-jquery-cookie'
    gem 'rails-assets-jsSHA'
  end
end

group :debugging do
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
end

group :development, :staging do
  gem 'rack-mini-profiler'
end

group :development, :test do
  gem 'bootsnap'
  gem 'awesome_print'
  gem 'brakeman'
  gem 'rubocop'
  gem 'rubocop-rails'
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
