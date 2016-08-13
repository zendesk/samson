# frozen_string_literal: true
class AddZendeskConfirmationToStages < ActiveRecord::Migration
  def change
    add_column :stages, :comment_on_zendesk_tickets, :boolean
  end
end
