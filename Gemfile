source 'https://rubygems.org'

# Heroku
ruby '1.9.3', :engine => 'jruby', :engine_version => '1.7.4'

gem 'rails', '4.0.0'

gem 'sqlite3', :platform => :ruby

platform :jruby do
  gem 'jdbc-sqlite3'
  gem 'activerecord-jdbcsqlite3-adapter'
end

gem 'sass-rails', '~> 4.0.0'

gem 'uglifier', '>= 1.3.0'

gem 'jquery-rails'
gem 'jquery-ui-rails'

gem "puma"

gem "omniauth", "~> 1.1"
gem "omniauth-oauth2", "~> 1.1"

gem 'anjlab-bootstrap-rails', :require => 'bootstrap-rails',
  :git => 'https://github.com/anjlab/bootstrap-rails.git', :branch => '3.0.0'
gem 'bootstrap-glyphicons'

gem "soft_deletion", "~> 0.4"

gem "state_machine", "~> 1.2"

gem "resque", "~> 1.24"

gem "net-ssh", "~> 2.1.0"
gem "net-ssh-shell", "~> 0.2"

gem "foreman"

gem "active_hash", "~> 1.0"

gem "ansible"

group :development do
  platform :ruby do
    gem "better_errors"
    gem "binding_of_caller"
  end
end
