# frozen_string_literal: true
class DePolyReleaseAuthor < ActiveRecord::Migration[5.2]
  def change
    remove_column :releases, :author_type
  end
end
