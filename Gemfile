source 'https://rubygems.org'

gem 'rails', '4.0.2'
gem 'puma'
gem 'dotenv-rails', '~> 0.9.0'

group :production do
  gem 'rails_12factor'
  gem 'mysql2', :platform => :ruby

  platform :jruby do
    gem 'activerecord-jdbcpostgresql-adapter'
    gem 'activerecord-jdbcmysql-adapter'
  end
end

group :assets do
  gem 'sass-rails', '~> 4.0.0'

  gem 'uglifier', '>= 1.3.0'

  gem 'jquery-rails'
  gem 'jquery-ui-rails'

  gem 'bootstrap-sass', :git => 'https://github.com/thomas-mcdonald/bootstrap-sass.git'
end

group :no_preload do
  gem 'omniauth', '~> 1.1'
  gem 'omniauth-oauth2', '~> 1.1'

  gem 'soft_deletion', '~> 0.4'

  gem 'state_machine', '~> 1.2'

  gem 'net-ssh', '~> 2.1'
  gem 'net-ssh-shell', '~> 0.2', :git => 'https://github.com/9peso/net-ssh-shell.git'

  gem 'active_hash', '~> 1.0'

  gem 'ansible'

  gem 'rbtrace'
end

group :development do
  gem 'sqlite3', :platform => :ruby

  platform :jruby do
    gem 'jdbc-sqlite3'
    gem 'activerecord-jdbcsqlite3-adapter'
    gem 'ruby-debug'
  end

  platform :ruby do
    gem 'better_errors'
    gem 'binding_of_caller'
  end
end

group :test do
  gem 'minitest-rails', '~> 0.9'
  gem 'minitest-metadata', :require => false
  gem 'bourne'
  gem 'webmock'
end

group :deployment do
  gem 'zendesk_deployment', :git => 'git@github.com:zendesk/zendesk_deployment.git', :tag  => 'v1.5.0'
end

