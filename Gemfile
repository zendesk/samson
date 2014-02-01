source 'https://rubygems.org'

gem 'dotenv-rails', '~> 0.9.0'
gem 'rails', '4.0.2'
gem 'puma'

gem 'sqlite3'
gem 'mysql2', '~> 0.3'

gem 'kaminari'
gem 'soft_deletion', '~> 0.4'
gem 'dalli', '~> 2.7.0'
gem 'coderay', '~> 1.1.0', require: false

gem 'angularjs-rails'
gem 'jbuilder'

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

  gem 'net-ssh', '~> 2.1'
  gem 'net-ssh-shell', '~> 0.2', :git => 'https://github.com/9peso/net-ssh-shell.git'

  gem 'active_hash', '~> 1.0'

  gem 'ansible'

  gem 'github-markdown', '~> 0.6.3'

  gem 'newrelic_api'
  gem 'activeresource'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
end

group :test do
  gem 'minitest-rails', '~> 0.9'
  gem 'bourne'
  gem 'webmock', :require => false
  gem 'simplecov', :require => false
end

group :deployment do
  gem 'zendesk_deployment', :git => 'git@github.com:zendesk/zendesk_deployment.git', :ref => 'v1.6.0'
end
