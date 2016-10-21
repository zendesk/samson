# frozen_string_literal: true
class AddJenkinsEmailCommittersToStage < ActiveRecord::Migration[5.0]
  def change
    add_column :stages, :jenkins_email_committers, :boolean, default: false, null: false
  end
end
