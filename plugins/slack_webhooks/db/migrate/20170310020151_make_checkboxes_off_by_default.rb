# frozen_string_literal: true
class MakeCheckboxesOffByDefault < ActiveRecord::Migration[5.0]
  def change
    change_column_default :slack_webhooks, :after_deploy, false
  end
end
