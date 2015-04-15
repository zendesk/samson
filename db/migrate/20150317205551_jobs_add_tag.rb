class JobsAddTag < ActiveRecord::Migration
  def change
    add_column :jobs, :tag, :string
  end
end
