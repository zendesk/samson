# frozen_string_literal: true
source 'https://rubygems.org'

ruby File.read('.ruby-version').strip

# gems that have rails engines are are always needed
group :preload do
  gem 'rails', '5.0.1'
  gem 'dotenv'
  gem 'sse-rails-engine'
  gem 'connection_pool'
  gem 'marco-polo'

  # AR extensions
  gem 'goldiloader'
  gem 'kaminari', '~> 0.17.0'
  gem 'active_model_serializers'
  gem 'paper_trail'
  gem 'soft_deletion'
  gem 'doorkeeper'

  # Logging
  gem 'lograge'
  gem 'logstash-event'
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
gem 'omniauth-gitlab', '~> 1.0.0'
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
gem 'docker-api', '>= 1.32'
gem 'newrelic_rpm'

# treat included plugins like gems
Dir[File.join(Bundler.root, 'plugins/*/')].each { |f| gemspec path: f }

gem 'sucker_punch', '~> 2.0'

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
  gem 'angular-rails-templates'
  gem 'bootstrap-sass'

  source 'https://rails-assets.org' do
    gem 'rails-assets-angular'
    gem 'rails-assets-angular-mocks'
    gem 'rails-assets-angular-scenario'
    gem 'rails-assets-spin'
    gem 'rails-assets-angular-spinner'
    gem 'rails-assets-bootstrap-select'
    gem 'rails-assets-font-awesome'
    gem 'rails-assets-jquery'
    gem 'rails-assets-jquery-ui'
    gem 'rails-assets-jquery-ujs'
    gem 'rails-assets-moment'
    gem 'rails-assets-rickshaw'
    gem 'rails-assets-typeahead.js'
    gem 'rails-assets-underscore'
    gem 'rails-assets-vis', '~> 4.10.0'
    gem 'rails-assets-x-editable'
    gem 'rails-assets-message-center'
    gem 'rails-assets-angular-ui-router'
    gem 'rails-assets-angular-truncate-2'
    gem 'rails-assets-jstimezonedetect'
    gem 'rails-assets-jquery-cookie'
    gem 'rails-assets-datatables.net'
    gem 'rails-assets-datatables.net-bs'
    gem 'rails-assets-datatables.net-fixedcolumns'
    gem 'rails-assets-datatables.net-fixedcolumns-bs'
  end
end

group :development, :staging do
  gem 'binding_of_caller'
  gem 'better_errors'
  gem 'rack-mini-profiler'
end

group :development, :test do
  gem 'byebug'
  gem 'bootscale'
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
  gem 'minitest-rails', '3.0.0'
  gem 'rails-controller-testing'
  gem 'maxitest'
  gem 'mocha'
  gem 'webmock'
  gem 'single_cov'
  gem 'query_diet', '0.6.1'
  gem 'ar_multi_threaded_transactional_tests'
  gem 'bundler-audit', require: false
end
