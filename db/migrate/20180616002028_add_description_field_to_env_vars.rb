class AddDescriptionFieldToEnvVars < ActiveRecord::Migration[5.2]
  def change
    add_column :environment_variables, :description, :text
  end
end
