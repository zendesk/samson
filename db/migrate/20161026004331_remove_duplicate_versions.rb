# frozen_string_literal: true
class RemoveDuplicateVersions < ActiveRecord::Migration[5.0]
  def up
    # delete all versions that are not unique
    PaperTrail::Version.connection.execute <<-SQL
      delete from versions where id not in (
        SELECT * FROM (select min(id) from versions group by item_id, item_type, object) AS temp_tab
      )
    SQL
  end

  def down
  end
end
