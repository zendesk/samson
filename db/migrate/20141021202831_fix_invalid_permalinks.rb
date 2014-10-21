class FixInvalidPermalinks < ActiveRecord::Migration
  def change
    [Stage, Project].each do |klass|
      klass.with_deleted do
        klass.find_each do |object|
          object.permalink = object.permalink.parameterize
          object.save if object.permalink_changed?
        end
      end
    end
  end
end
