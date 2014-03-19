class AddGithubConfirmationToStages < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.boolean :update_pr
    end
  end
end
