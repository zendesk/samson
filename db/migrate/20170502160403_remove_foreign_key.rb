# frozen_string_literal: true
class RemoveForeignKey < ActiveRecord::Migration[5.0]
  def up
    remove_foreign_key "deploy_groups", "environments" if foreign_key_exists?("deploy_groups", "environments")
  end

  def down
    add_foreign_key "deploy_groups", "environments"
  end
end
