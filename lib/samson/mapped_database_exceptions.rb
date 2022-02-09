# frozen_string_literal: true

module Samson
  module MappedDatabaseExceptions
    class ServerGoneAway < ActiveRecord::StatementInvalid;
    end

    def execute(...)
      super
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?('MySQL server has gone away')
        raise ServerGoneAway
      end

      raise
    end
  end
end

if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
  ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(Samson::MappedDatabaseExceptions)
end
