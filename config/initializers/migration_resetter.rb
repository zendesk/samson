# frozen_string_literal: true
# reset schema after each migration so removed/added columns are visible
# some users will run super old migrations all at once and then get unexpected errors when columns are missing/present
#
# to reproduce, add 2 migrations one that removes a column and one that puts Stage.column_hash to see if it removed
# an even safer (but slower/hackier) option would be to reset after each column change
ActiveRecord::Migration.prepend(
  Module.new do
    def exec_migration(*)
      ActiveRecord::Base.connection.schema_cache.clear!
      super
    end
  end
)
