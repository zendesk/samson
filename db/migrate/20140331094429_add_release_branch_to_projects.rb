# frozen_string_literal: true
class AddReleaseBranchToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :release_branch, :string
  end
end
