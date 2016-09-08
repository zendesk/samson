# frozen_string_literal: true
class AddZendeskConfirmationToStages < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :comment_on_zendesk_tickets, :boolean
  end
end
