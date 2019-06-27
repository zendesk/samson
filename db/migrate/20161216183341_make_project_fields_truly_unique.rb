# frozen_string_literal: true
class MakeProjectFieldsTrulyUnique < ActiveRecord::Migration[5.0]
  class Project < ActiveRecord::Base
  end

  class Stage < ActiveRecord::Base
  end

  def up
    # make duplicate permalinks unique
    [Project, Stage].each do |klass|
      klass.where.not(deleted_at: nil).each do |p|
        next if p.permalink.include?('-deleted-')
        write "Updating #{klass} #{p.id}"
        p.update_column(:permalink, "#{p.permalink}-deleted-#{p.deleted_at.to_i}")
      end
    end

    add_index :projects, :permalink, unique: true, length: {permalink: 191}
    remove_index :projects, [:permalink, :deleted_at]

    add_index :stages, [:project_id, :permalink], unique: true, length: {permalink: 191}
    remove_index :stages, [:project_id, :permalink, :deleted_at]

    add_index :projects, :token, unique: true, length: {token: 191}
    remove_index :projects, [:token, :deleted_at]
  end

  def down
    add_index :projects, [:permalink, :deleted_at], unique: true, length: {permalink: 191}
    remove_index :projects, :permalink

    add_index :stages, [:project_id, :permalink, :deleted_at], unique: true, length: {permalink: 191}
    remove_index :stages, [:project_id, :permalink]

    add_index :projects, [:token, :deleted_at], unique: true, length: {token: 191}
    remove_index :projects, :token
  end
end
