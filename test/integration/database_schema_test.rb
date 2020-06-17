# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

describe "database schema" do
  let_all(:table_definitions) do
    tables = []

    conn = mock('adapter')
    conn.stub_everything
    conn.define_singleton_method(:create_table) do |name, *_, &blk|
      table = ActiveRecord::ConnectionAdapters::TableDefinition.new(conn, name)
      blk.call(table)
      tables << table
    end

    ActiveRecord::Schema.stub(:define, ->(*_, &blk) { conn.instance_eval(&blk) }) do
      load 'db/schema.rb'
    end

    tables.size.must_be :>, 10
    tables.freeze
  end

  def map_indexes
    table_definitions.flat_map do |table|
      table.indexes.map do |index|
        fields, opts = index
        yield table, fields, opts
      end.compact
    end.compact
  end

  it "does not have boolean limit 1 in schema since this breaks mysql" do
    table_definitions.
      flat_map(&:columns).
      select { |c| c.type == :boolean && c.options[:limit] == 1 }.
      must_be_empty
  end

  it "does not have limits too big for mysql/postgres in schema" do
    table_definitions.flat_map do |table|
      table.columns.map do |column|
        if column.options[:limit] && column.options[:limit] > 1073741823
          "#{table.name} #{column.name} has too large of a limit... use 1073741823 or lower"
        end
      end.compact
    end
  end

  it "does not have string index without limit since that breaks our mysql migrations" do
    bad = map_indexes do |table, fields, opts|
      strings = table.columns.select { |c| c.type == :string }.map(&:name)
      index_strings = fields & strings
      length = opts[:length]

      if index_strings.present? && length.nil?
        [table.name, *index_strings]
      elsif length.is_a? Hash
        columns_with_length = length.keys.map(&:to_s) || []
        without_length = index_strings - columns_with_length

        [table.name, *without_length] if without_length.present?
      end
    end

    # old tables that somehow worked
    bad -= [
      ["builds", "git_sha", "dockerfile"],
      ["environment_variable_groups", "name"],
      ["environments", "permalink"],
      ["jobs", "status"],
      ["kubernetes_roles", "name"],
      ["kubernetes_roles", "service_name"],
      ["new_relic_applications", "name"],
      ["releases", "number"],
      ["users", "external_id"],
      ["webhooks", "branch"]
    ]

    bad.map! { |table, *fields| "#{table} #{fields.join(',')} has a string index without length" }.join("\n")
    assert bad.empty?, bad
  end

  it "does not have string index with limit > 191 characters" do
    # default mysql index key prefix length limit is 767 bytes
    # using utf8mb4, this equates to 191 characters

    bad = map_indexes do |table, fields, opts|
      strings = table.columns.select { |c| c.type == :string }.map(&:name)
      index_strings = fields & strings
      length = opts[:length]

      next if index_strings.empty?
      next if length.nil?
      next if length.is_a?(Integer) && length < 192
      next if length.is_a?(Hash) && length.stringify_keys.slice(*index_strings).all? { |_, l| l < 192 }

      [table.name, *fields]
    end

    bad.map! { |table, *fields| "#{table} #{fields.join(',')} has a string index with length > 191" }.join("\n")
    assert bad.empty?, bad
  end

  it "has created/updated for all tables" do
    bad = table_definitions.reject { |t| t[:created_at] && t[:updated_at] }.map(&:name)

    # ignored tables
    bad -= [
      "audits",
      "deploy_groups_stages",
      "environment_variables",
      "environment_variable_groups",
      "kubernetes_deploy_group_roles",
      "kubernetes_stage_roles",
      "new_relic_applications",
      "oauth_access_grants",
      "oauth_access_tokens",
      "project_environment_variable_groups",
      "versions"
    ]

    bad.map! { |table, _| "#{table} needs updated_at/created_at or be ignored here" }.join("\n")
    assert bad.empty?, bad
  end

  it "does not have 3-state booleans (nil/false/true)" do
    bad = table_definitions.
      flat_map(&:columns).
      select { |c| c.type == :boolean && c.options[:null] != false }.
      map(&:name)

    assert bad.empty?, "Boolean columns missing a default or null: false\n#{bad.join("\n")}"
  end
end
