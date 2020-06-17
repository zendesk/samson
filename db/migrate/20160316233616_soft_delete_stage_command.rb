# frozen_string_literal: true
class SoftDeleteStageCommand < ActiveRecord::Migration[4.2]
  def change
    add_column :stage_commands, :deleted_at, :datetime

    # Mark all old StageCommand as deleted
    deleted_stages = Stage.with_deleted { Stage.where('deleted_at IS NOT NULL').pluck(:id) }
    StageCommand.where(stage_id: deleted_stages).update_all(deleted_at: Time.now)
  end
end
