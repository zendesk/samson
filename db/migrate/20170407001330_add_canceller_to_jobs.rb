# frozen_string_literal: true
class AddCancellerToJobs < ActiveRecord::Migration[5.0]
  def change
    add_column :jobs, :canceller_id, :integer
  end
end
