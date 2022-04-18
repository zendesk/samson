# frozen_string_literal: true

require_relative '../../test_helper'

if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter) # Only used when using mysql
  SingleCov.covered! uncovered: 1

  describe Samson::MappedDatabaseExceptions do
    describe '#execute' do
      def invalid_sql
        assert_raises ActiveRecord::StatementInvalid do
          Project.where('oops').count
        end.class
      end

      it 'allows other statement invalid errors to be raised' do
        invalid_sql.must_equal ActiveRecord::StatementInvalid
      end

      it 'rescues the server has gone away error and raises our own' do
        ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.any_instance.expects(:log).raises(
          ActiveRecord::StatementInvalid,
          'MySQL server has gone away'
        )

        invalid_sql.must_equal Samson::MappedDatabaseExceptions::ServerGoneAway
      end
    end
  end
end
