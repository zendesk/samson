source 'https://rubygems.org'

gem 'dotenv-rails', '~> 0.9.0'
gem 'rails', '4.0.4'
gem 'puma'

gem 'sqlite3'
gem 'mysql2', '~> 0.3'

gem 'kaminari'
gem 'soft_deletion', '~> 0.4'
gem 'dalli', '~> 2.7.0'
gem 'active_model_serializers', '~> 0.8.0'

# We need this specific version of Sawyer (which Octokit uses) because it supports
# marshalling resources, which we use when caching responses. Once that's been released
# we can use a normal gem version again.
gem 'sawyer', git: 'https://github.com/dasch/sawyer.git', branch: 'dasch/fix-marshal-problem'

group :production, :staging do
  gem 'rails_12factor'
  gem 'airbrake'
  gem 'newrelic_rpm', '>= 3.7.1'
end

group :assets do
  gem 'sass-rails', '~> 4.0.0'

  gem 'uglifier', '>= 1.3.0'

  gem 'jquery-rails'
  gem 'jquery-ui-rails'

  gem 'bootstrap-sass'
  gem 'font-awesome-sass'

  gem 'bootstrap-x-editable-rails'

  gem 'rickshaw_rails'

  gem 'angularjs-rails'

  gem 'momentjs-rails'
end

group :no_preload do
  gem 'omniauth', '~> 1.1'
  gem 'omniauth-oauth2', '~> 1.1'
  gem 'omniauth-github', '~> 1.1'

  gem 'faraday-http-cache', '~> 0.3'
  gem 'octokit', '~> 2.7.0'

  gem 'warden', '~> 1.2'

  gem 'flowdock', '~> 0.3.1'

  gem 'state_machine', '~> 1.2'

  gem 'active_hash', '~> 1.0'

  gem 'ansible'

  gem 'github-markdown', '~> 0.6.3'

  gem 'newrelic_api'
  gem 'activeresource'

  gem 'coderay', '~> 1.1.0'

  gem 'dogapi', '~> 1.9.1'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
end

group :test do
  gem 'minitest-rails', '~> 0.9'
  gem 'bourne'
  gem 'webmock', require: false
  gem 'simplecov', require: false
end

group :deployment do
  gem 'zendesk_deployment', git: 'git@github.com:zendesk/zendesk_deployment.git', ref: 'v1.9.4'
end
