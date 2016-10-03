# frozen_string_literal: true
class Remove3StateBooleans < ActiveRecord::Migration[5.0]
  def change
    change_column_null :stages, :confirm, false, false
    change_column_null :stages, :deploy_on_release, false, false
    change_column_null :stages, :production, false, false
    change_column_null :stages, :no_code_deployed, false, false
    change_column_null :users, :desktop_notify, false, false
    change_column_null :users, :access_request_pending, false, false
  end
end
