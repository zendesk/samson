# frozen_string_literal: true
class RemoveRedundantImageId < ActiveRecord::Migration[5.1]
  def change
    remove_column :builds, :docker_image_id, :string
  end
end
