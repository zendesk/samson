class AddNotifyEmailAddressToStages < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.string :notify_email_address
    end
  end
end
