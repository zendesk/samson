# frozen_string_literal: true
class AddPermalinkToEnvironments < ActiveRecord::Migration[4.2]
  def change
    add_column :environments, :permalink, :string
    add_index :environments, :permalink, unique: true, length: 191

    Environment.reset_column_information

    Environment.with_deleted do
      Environment.find_each do |environment|
        environment.send(:generate_permalink)
        environment.update_column(:permalink, environment.permalink)
      end
    end

    change_column :environments, :permalink, :string, null: false
  end
end
