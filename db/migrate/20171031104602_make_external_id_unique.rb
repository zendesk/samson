# frozen_string_literal: true
class MakeExternalIdUnique < ActiveRecord::Migration[5.1]
  class User < ActiveRecord::Base
  end

  def up
    # update the external_id of all uses that would violate the new uniqueness
    scope = User.where(deleted_at: nil)
    bad = scope.group(:external_id).count.select { |_, count| count.size >= 2 }
    bad.each_key do |id|
      duplicates = scope.where(external_id: id)
      duplicates[1..].each_with_index do |u, i|
        write "Updating user #{u.id} external_id"
        u.update_column :external_id, "#{id}-#{i}"
      end
    end

    remove_index :users, [:external_id, :deleted_at]
    add_index :users, [:external_id, :deleted_at], unique: true
  end

  def down
    remove_index :users, [:external_id, :deleted_at]
    add_index :users, [:external_id, :deleted_at]
  end
end
