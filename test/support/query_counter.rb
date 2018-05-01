# frozen_string_literal: true
# http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed/43810063#43810063
class ActiveSupport::TestCase
  # not on rails 5.1 payload[:name] could be used for finding schema queries, maybe fixed on 5.2/6.0
  SCHEMA_QUERIES = [
    "RELEASE SAVEPOINT", "SAVEPOINT", "SELECT column_name", "SHOW FULL FIELDS FROM", "SELECT a.attname",
    "PRAGMA table_info"
  ].freeze

  def sql_queries(&block)
    queries = []
    counter = ->(*, payload) do
      sql = payload.fetch(:sql).strip
      queries << sql unless sql.start_with?(*SCHEMA_QUERIES)
    end

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)

    queries
  end

  def assert_sql_queries(expected, &block)
    queries = sql_queries(&block)
    queries.count.must_equal(
      expected,
      "Expected #{expected} queries, but found #{queries.count}:\n#{queries.join("\n")}"
    )
    queries
  end
end
