class AddEmailSettingsToStages < ActiveRecord::Migration
  def change
    add_column :stages, :email_committers_on_automated_deploy_failure, :boolean, default: false, null: false
    add_column :stages, :static_emails_on_automated_deploy_failure, :string, limit: 255
    add_column :users, :integration, :boolean, default: false, null: false
    User.reset_column_information
    User.where(name: ["Jenkins", "Semaphore", "Tddium", "Github", "Travis"]).update_all(integration: true)
  end
end
