class StagePermalinkUniqueByProject < ActiveRecord::Migration
  def change
    add_index :stages, [:project_id, :permalink], unique: true
    remove_index :stages, column: [:permalink]

    Stage.find_each do |stage|
      root, hash = stage.permalink.split("-",2)
      if hash =~ /^[a-f\d]{8}$/ && !stage.project.stages.where(permalink: root).exists?
        stage.update_attribute(:permalink, root)
      end
    end
  end
end
