# We would like to be able to create an index on a string that is larger than 191 characters
# We also want our mysql databases to use utf8_mb4 encoding (the real unicode)
# This monkey patch is from the following Github comment:
# https://github.com/rails/rails/issues/9855#issuecomment-57665404
config = ActiveRecord::Base.configurations[Rails.env]

if ENV['USE_UTF8MB4'] && config['adapter'] == 'mysql2' && RUBY_ENGINE != "jruby"
  config.merge!(
    'encoding' => 'utf8mb4',
    'collation' => 'utf8mb4_bin'
  )

  module ActiveRecord
    module ConnectionAdapters
      class Mysql2Adapter < AbstractMysqlAdapter
        def create_table(table_name, options = {}) #:nodoc:
          super(table_name, options.reverse_merge(options: "ROW_FORMAT=DYNAMIC ENGINE=InnoDB"))
        end
      end
    end
  end
end
