class AddJenkinsEmailCommittersToStage < ActiveRecord::Migration[5.0]
  def change
    add_column :stages, :jenkins_email_committers, :boolean
  end
end
