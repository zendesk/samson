# frozen_string_literal: true
class RenameBuildColumns < ActiveRecord::Migration[4.2]
  def change
    change_table :builds do |t|
      t.rename :container_sha, :docker_sha
      t.rename :container_ref, :docker_ref
    end
  end
end
