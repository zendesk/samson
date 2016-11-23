# frozen_string_literal: true
class AddProjectIdToDeploys < ActiveRecord::Migration[5.0]
  class Deploy < ActiveRecord::Base
  end

  class Stage < ActiveRecord::Base
  end

  def up
    add_column :deploys, :project_id, :integer

    map = Stage.pluck(:project_id, :id).each_with_object({}) { |(p, s), all| (all[p] ||= []) << s }
    map.each do |project_id, stage_ids|
      Deploy.where(stage_id: stage_ids).update_all(project_id: project_id)
    end

    change_column_null :deploys, :project_id, false
    add_index :deploys, [:project_id, :deleted_at]
  end

  def down
    remove_column :deploys, :project_id
  end
end
