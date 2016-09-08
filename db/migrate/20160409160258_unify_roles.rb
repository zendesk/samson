# frozen_string_literal: true
class UnifyRoles < ActiveRecord::Migration[4.2]
  UP = {
    2 => 3,
    1 => 2
  }.freeze

  DOWN = {
    2 => 1,
    3 => 2
  }.freeze

  def up
    map!(UP)
  end

  def down
    map!(DOWN)
  end

  def map!(directions)
    directions.each do |old, new|
      UserProjectRole.where(role_id: old).update_all(role_id: new)
    end

    # remove unnecessary default role
    UserProjectRole.where('role_id not in (?)', directions.values).delete_all
  end
end
