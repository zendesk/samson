class SoftDeleteStageCommand < ActiveRecord::Migration
  def change
    add_column :stage_commands, :deleted_at, :timestamp

    # Mark all old StageCommand as deleted
    deleted_stages = Stage.with_deleted { Stage.where('deleted_at IS NOT NULL').pluck(:id) }
    StageCommand.where(stage_id: deleted_stages).update_all(deleted_at: Time.now)
  end
end
