# frozen_string_literal: true
class DeleteKubernetesCommands < ActiveRecord::Migration[5.0]
  class Stage < ActiveRecord::Base
    self.table_name = :stages
  end

  class StageCommand < ActiveRecord::Base
    self.table_name = :stage_commands
  end

  def change
    stage_ids = Stage.where(kubernetes: true).pluck(:id)
    StageCommand.where(stage_id: stage_ids).delete_all
  end
end
