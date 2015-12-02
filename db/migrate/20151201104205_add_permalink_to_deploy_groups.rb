class AddPermalinkToDeployGroups < ActiveRecord::Migration
  def change
    add_column :deploy_groups, :permalink, :string
    add_index :deploy_groups, :permalink, unique: true

    DeployGroup.reset_column_information

    DeployGroup.with_deleted do
      DeployGroup.find_each do |deploy_group|
        deploy_group.send(:generate_permalink)
        deploy_group.update_column(:permalink, deploy_group.permalink)
      end
    end

    change_column :deploy_groups, :permalink, :string, null: false
  end
end
