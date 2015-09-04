class AddNumberToBuilds < ActiveRecord::Migration
  def change
    change_table :builds do |t|
      t.integer :number, after: :project_id
    end

    Release.joins(:build).update_all('builds.number = releases.number')
  end
end
