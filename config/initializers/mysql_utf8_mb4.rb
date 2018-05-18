# frozen_string_literal: true
# We would like to be able to create an index on a string that is larger than 191 characters
# We also want our mysql databases to use utf8_mb4 encoding (the real unicode)
# This monkey patch is from the following Github comment:
# https://github.com/rails/rails/issues/9855#issuecomment-57665404
config = ActiveRecord::Base.configurations[Rails.env]

if ENV['USE_UTF8MB4'] && config['adapter'] == 'mysql2'
  config['encoding'] = 'utf8mb4'
  config['collation'] = 'utf8mb4_bin'

  ActiveRecord::ConnectionAdapters::Mysql2Adapter.class_eval do
    # enhance included create_table method
    def create_table(table_name, options = {}) #:nodoc:
      sql_options = options[:options] # always passed in via lib/active_record/migration/compatibility.rb
      sql_options = "ROW_FORMAT=DYNAMIC #{sql_options}" unless sql_options.to_s.include?("ROW_FORMAT")
      super(table_name, options.merge(options: sql_options))
    end
  end
end
