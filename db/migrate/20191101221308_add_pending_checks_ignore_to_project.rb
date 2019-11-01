# frozen_string_literal: true
class AddPendingChecksIgnoreToProject < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :ignore_pending_checks, :string
  end
end
