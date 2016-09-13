# frozen_string_literal: true
class AddReleaseBranchToProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :release_branch, :string
  end
end
