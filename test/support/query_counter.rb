# frozen_string_literal: true
# http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed/43810063#43810063
class ActiveSupport::TestCase
  def sql_queries(&block)
    queries = []
    counter = ->(*, payload) do
      sql = payload.fetch(:sql)
      next if ["CACHE", "SCHEMA"].include?(payload.fetch(:name))
      next if sql.include?("SAVEPOINT")
      next if sql.include?("INSERT INTO")

      # resolve binds to make queries less generic (parent_type = ? -> parent_type = 'Project')
      # needed for sqlite which uses `?` and postgres which uses `$1,$2,...`
      # ideally find a builtin way of resolving binds
      payload[:type_casted_binds].each do |v|
        sql = sql.dup.sub!(/\?|\$\d+/, v.inspect) || raise("Unable to find placeholder for #{v.inspect}")
      end

      # show caller for easy debugging
      sql += " # from #{Rails.backtrace_cleaner.filter(caller).first(5).join(' / ')}"

      queries << sql
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

  def assert_nplus1_queries(expected, &block)
    queries = sql_queries(&block)
    queries = queries.group_by { |q| q.gsub(/\d+/, "DIGIT").split(" #").first }.select { |_, v| v.size > 1 }
    actual = queries.values.map { |v| v.size - 1 }.sum
    list = queries.map { |q, v| "#{q}:\n#{v.map { |x| "  #{x}" }.join("\n")}" }.join("\n")
    actual.must_equal(
      expected,
      "Expected #{expected} nplus1 queries, but found #{queries.count}:\n#{list}"
    )
  end
end
