# We would like to be able to create an index on a string that is larger than 191 characters
# We also want our mysql databases to use utf8_mb4 encoding (the real unicode)
# This monkey patch is from the following Github comment:
# https://github.com/rails/rails/issues/9855#issuecomment-57665404
if Gem.loaded_specs.has_key? 'mysql2'
  require 'active_record/connection_adapters/mysql2_adapter'

  module ActiveRecord
    module ConnectionAdapters
      class Mysql2Adapter < defined?(AbstractMysqlAdapter) ? AbstractMysqlAdapter : AbstractAdapter
        def create_table(table_name, options = {}) #:nodoc:
          puts "creating #{table_name} with dynamic and #{options.inspect}"
          super(table_name, options.reverse_merge(options: "ROW_FORMAT=DYNAMIC ENGINE=InnoDB"))
        end
      end
    end
  end
end
