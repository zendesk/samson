# frozen_string_literal: true

class AddSortableColumnForDeployGroups < ActiveRecord::Migration[5.2]
  class DeployGroup < ActiveRecord::Base
  end

  def change
    add_column :deploy_groups, :name_sortable, :string
    DeployGroup.find_each do |group|
      sortable = group.name.split(/(\d+)/).each_with_index.map { |x, i| i.odd? ? x.rjust(5, "0") : x }.join
      group.update_column(:name_sortable, sortable)
    end
    change_column_null :deploy_groups, :name_sortable, false
  end
end
