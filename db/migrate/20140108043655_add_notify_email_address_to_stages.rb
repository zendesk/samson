# frozen_string_literal: true
class AddNotifyEmailAddressToStages < ActiveRecord::Migration[4.2]
  def change
    change_table :stages do |t|
      t.string :notify_email_address
    end
  end
end
