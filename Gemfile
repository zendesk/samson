source 'https://rubygems.org'

ruby File.read('.ruby-version').strip

# gems that have rails engines are are always needed
group :preload do
  gem 'rails', '~> 4.2.0'
  gem 'dotenv'
  gem 'sse-rails-engine'

  # AR extensions
  gem 'goldiloader'
  gem 'kaminari'
  gem 'active_model_serializers'
  gem 'paper_trail'
  gem 'soft_deletion'

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

# Temporarily using our fork, while waiting for this PR to get merged:
# https://github.com/abonas/kubeclient/pull/127
gem 'kubeclient', github: 'zendesk/kubeclient', branch: 'samson-gem-branch'

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
  gem 'airbrake', '~> 4.3.6' # different configuration format on 5.x
  gem 'newrelic_rpm'
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
    gem 'rails-assets-angular-ui-bootstrap-bower'
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
    gem 'rails-assets-vis'
    gem 'rails-assets-x-editable'
    gem 'rails-assets-message-center'
    gem 'rails-assets-angular-ui-router'
    gem 'rails-assets-angular-truncate-2'
    gem 'rails-assets-jstimezonedetect'
    gem 'rails-assets-jquery-cookie'
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
  gem 'awesome_print'
  gem 'brakeman'
  gem 'rubocop'
end

group :test do
  gem 'minitest-rails'
  gem 'maxitest'
  gem 'mocha'
  gem 'webmock'
  gem 'single_cov'
  gem 'simplecov'
  gem 'query_diet'
  gem 'codeclimate-test-reporter'
end
