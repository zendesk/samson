# frozen_string_literal: true

# evil hack to get db-pools when using an environment like heroku that only provides DATABASE_URL
# https://devcenter.heroku.com/articles/concurrency-and-database-connections
# deprecated and should no longer be used ... need to replace this with a nice solution for heroku,
# for now just showing warnings

pool = Integer(ENV['DB_POOL'] || ENV['RAILS_MAX_THREADS'] || 100)

if !ENV['PRECOMPILE'] && (config = Rails.application.config.database_configuration[Rails.env]) && config['pool'] != pool
  warn <<-WARN.strip_heredoc
    Currently using an evil ActiveRecord patch that will be removed soon.
     - Add to database.yml `pool: <%= ENV['RAILS_MAX_THREADS'] %>`
     - Add to environment RAILS_MAX_THREADS=100

    See https://devcenter.heroku.com/articles/concurrency-and-database-connections
    From: config/initializers/db_pool_from_env.rb
  WARN

  Rails.application.config.after_initialize do
    ActiveRecord::Base.connection_pool.disconnect!

    ActiveSupport.on_load(:active_record) do
      config['pool'] = pool
      ActiveRecord::Base.establish_connection(config)
    end
  end
end
