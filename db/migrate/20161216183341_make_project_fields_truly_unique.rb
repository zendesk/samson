# frozen_string_literal: true
class MakeProjectFieldsTrulyUnique < ActiveRecord::Migration[5.0]
  class Project < ActiveRecord::Base
  end

  class Stage < ActiveRecord::Base
  end

  def up
    # make duplicate permalinks unique
    Project.group(:permalink).count.select do |permalink, count|
      next if count == 1
      Project.where(permalink: permalink).each do |p|
        if p.deleted_at?
          puts "Updating project #{p.id}"
          p.update_column(:permalink, "#{p.permalink}-deleted-#{p.deleted_at.to_i}")
        end
      end
    end

    Stage.with_deleted do
      Stage.group(:permalink, :project_id).count.select do |(permalink, project_id), count|
        next if count == 1
        Stage.where(permalink: permalink, project_id: project_id).each do |s|
          if s.deleted_at?
            puts "Updating stage #{s.id}"
            s.update_column(:permalink, "#{s.permalink}-deleted-#{s.deleted_at.to_i}")
          end
        end
      end
    end

    add_index :projects, :permalink, unique: true, length: { permalink: 191 }
    remove_index :projects, [:permalink, :deleted_at]

    add_index :stages, [:project_id, :permalink], unique: true, length: { permalink: 191 }
    remove_index :stages, [:project_id, :permalink, :deleted_at]

    add_index :projects, :token, unique: true, length: { token: 191 }
    remove_index :projects, [:token, :deleted_at]
  end

  def down
    add_index :projects, [:permalink, :deleted_at], unique: true, length: { permalink: 191 }
    remove_index :projects, :permalink

    add_index :stages, [:project_id, :permalink, :deleted_at], unique: true, length: { permalink: 191 }
    remove_index :stages, [:project_id, :permalink]

    add_index :projects, [:token, :deleted_at], unique: true, length: { token: 191 }
    remove_index :projects, :token
  end
end
