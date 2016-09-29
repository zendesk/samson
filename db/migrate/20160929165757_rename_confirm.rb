class RenameConfirm < ActiveRecord::Migration[5.0]
  def change
    rename_column :stages, :confirm, :review_before_deploying
    change_column_default :stages, :review_before_deploying, false
  end
end
