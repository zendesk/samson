if Gem.loaded_specs.has_key? :mysql2
  require 'active_record/connection_adapters/mysql2_adapter'

  module ActiveRecord
    module ConnectionAdapters
      class Mysql2Adapter < defined?(AbstractMysqlAdapter) ? AbstractMysqlAdapter : AbstractAdapter
        def create_table(table_name, options = {}) #:nodoc:
          super(table_name, options.reverse_merge(:options => "ROW_FORMAT=DYNAMIC ENGINE=InnoDB"))
        end
      end
    end
  end
end
