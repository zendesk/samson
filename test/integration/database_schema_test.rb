# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

describe "database schema" do
  attr_reader :table_definitions

  before(:all) do
    tables = []

    conn = mock('adapter').responds_like_instance_of(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter)
    conn.stub_everything
    conn.define_singleton_method(:create_table) do |name, *_, &blk|
      table = ActiveRecord::ConnectionAdapters::TableDefinition.new(name)
      blk.call(table)
      tables << table
    end

    ActiveRecord::Schema.stub(:define, ->(*_, &blk) { conn.instance_eval(&blk) }) do
      load 'db/schema.rb'
    end

    tables.size.must_be :>, 10
    @table_definitions = tables.freeze
  end

  it "does not have boolean limit 1 in schema since this breaks mysql" do
    table_definitions.
      flat_map(&:columns).
      select { |c| c.type == :boolean && c.options[:limit] == 1 }.
      must_be_empty
  end

  it "does not have limits too big for postgres in schema" do
    table_definitions.flat_map do |table|
      table.columns.map do |column|
        if column.options[:limit] && column.options[:limit] > 1073741823
          "#{table.name} #{column.name} has too large of a limit... use 1073741823 or lower"
        end
      end.compact
    end
  end

  it "does not have string index without limit since that breaks our mysql migrations" do
    bad = table_definitions.flat_map do |table|
      strings = table.columns.select { |c| c.type == :string }.map(&:name)
      table.indexes.map do |index|
        opts = index[1]
        length = opts[:length]
        if length.is_a? Hash
          index_strings = index[0] & strings
          columns_with_length = length&.keys&.map(&:to_s) || []
          without_length = index_strings - columns_with_length

          [table.name, *without_length] if without_length.present?
        end
      end.compact
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

    bad.map! { |table, string| "#{table} #{string} has a string index without length" }.join("\n")
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
