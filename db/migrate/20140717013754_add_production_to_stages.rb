class AddProductionToStages < ActiveRecord::Migration
  def change
    add_column :stages, :comment_on_zendesk_tickets, :boolean, default: false
    add_column :stages, :production, :boolean, default: false
  end
end
