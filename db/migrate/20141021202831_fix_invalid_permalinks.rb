# frozen_string_literal: true
class FixInvalidPermalinks < ActiveRecord::Migration[4.2]
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
