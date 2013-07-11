ENV['RACK_ENV'] = 'test'
ENV['DATABASE_URL'] = "mysql://root@localhost/pusher_test"

require 'bundler/setup'

require Bundler.root.join('routes', 'pusher')

require 'rspec'
require 'rack/test'
require 'database_cleaner'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  def app
    Pusher
  end
end
