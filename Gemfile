source 'https://rubygems.org'
source 'https://rails-assets.org'

gem 'bundler'

gem 'rails', '~> 4.2.0'
gem 'puma'
gem 'dotenv-rails', '~> 0.9'

gem 'dogstatsd-ruby', '~> 1.4.0', require: 'statsd'
gem 'goldiloader'

group :mysql2 do
  gem 'mysql2', '~> 0.3'
end

group :postgres do
  gem 'pg', '~> 0.13'
end

group :sqlite do
  gem "sqlite3"
end

gem 'kaminari'
gem 'soft_deletion', '~> 0.4'
gem 'dalli', '~> 2.7.0'
gem 'active_model_serializers', '~> 0.8.0'

gem 'sawyer', '~> 0.5'
gem 'sse-rails-engine'

# Logging
gem 'lograge'
gem 'logstash-event'

group :production, :staging do
  gem 'rails_12factor'
  gem 'airbrake', '~> 4.1.0'
  gem 'newrelic_rpm', '>= 3.7.1'
end

group :assets do
  gem 'ngannotate-rails'
  gem 'sass-rails', '~> 5.0'
  gem 'uglifier', '>= 1.3.0'
  gem 'angular-rails-templates'
  gem 'bootstrap-sass'

  gem 'rails-assets-angular'
  gem 'rails-assets-angular-mocks'
  gem 'rails-assets-angular-scenario'
  gem 'rails-assets-bootstrap-select'
  gem 'rails-assets-font-awesome'
  gem 'rails-assets-jquery'
  gem 'rails-assets-jquery-ui'
  gem 'rails-assets-jquery-ujs'
  gem 'rails-assets-moment'
  gem 'rails-assets-rickshaw'
  gem 'rails-assets-typeahead.js'
  gem 'rails-assets-underscore'
  gem 'rails-assets-vis'
  gem 'rails-assets-x-editable'
end

group :no_preload do
  gem 'omniauth', '~> 1.1'
  gem 'omniauth-oauth2', '~> 1.1'
  gem 'omniauth-github', '= 1.1.1'
  gem 'omniauth-google-oauth2', '~> 0.2.4'
  gem 'octokit', '~> 3.0'
  gem 'faraday-http-cache', '~> 0.4'
  gem 'warden', '~> 1.2'
  gem 'active_hash', '~> 1.0'
  gem 'ansible'
  gem 'github-markdown', '~> 0.6.3'
  gem 'newrelic_api'
  gem 'activeresource'
  gem 'coderay', '~> 1.1.0'
  gem 'dogapi', '~> 1.9'
  gem 'net-http-persistent'
  Dir["plugins/*/"].each { |f| gemspec path: f } # treat included plugins like gems
end

group :development, :staging do
  gem 'web-console'
  gem 'rack-mini-profiler'
end

group :development, :test do
  gem 'byebug', require: false
end

group :test do
  gem 'minitest-rails'
  gem 'maxitest'
  gem 'mocha', require: false
  gem 'webmock', require: false
  gem 'simplecov', require: false
  gem 'query_diet'
  gem 'codeclimate-test-reporter', require: false
end
