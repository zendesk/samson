# frozen_string_literal: true
class StagePermalinkUniqueByProject < ActiveRecord::Migration[4.2]
  def change
    add_index :stages, [:project_id, :permalink], unique: true, length: {permalink: 191}
    remove_index :stages, column: [:permalink]

    Stage.find_each do |stage|
      next unless stage.project
      root, hash = stage.permalink.split("-", 2)
      if hash =~ /^[a-f\d]{8}$/ && !stage.project.stages.where(permalink: root).exists?
        stage.update_attribute(:permalink, root)
      end
    end
  end
end
