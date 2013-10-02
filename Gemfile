source 'https://rubygems.org'

# Heroku
ruby '1.9.3', :engine => 'jruby', :engine_version => '1.7.4'

gem 'rails', '4.0.0'

group :production do
  gem 'rails_12factor'
  gem 'activerecord-jdbcpostgresql-adapter'
end

group :assets do
  gem 'sass-rails', '~> 4.0.0'

  gem 'uglifier', '>= 1.3.0'

  gem 'jquery-rails'
  gem 'jquery-ui-rails'

  gem 'bootstrap-sass', :git => 'https://github.com/thomas-mcdonald/bootstrap-sass.git'
end

gem "puma"

gem "omniauth", "~> 1.1"
gem "omniauth-oauth2", "~> 1.1"

gem "soft_deletion", "~> 0.4"

gem "state_machine", "~> 1.2"

gem "redis", "~> 3.0"

gem "net-ssh", "~> 2.1"
gem "net-ssh-shell", "~> 0.2", :git => 'https://github.com/9peso/net-ssh-shell.git'

gem "foreman"

gem "active_hash", "~> 1.0"

gem "ansible"

group :development do
  gem 'sqlite3', :platform => :ruby

  platform :jruby do
    gem 'jdbc-sqlite3'
    gem 'activerecord-jdbcsqlite3-adapter'
  end

  platform :ruby do
    gem "better_errors"
    gem "binding_of_caller"
  end
end
