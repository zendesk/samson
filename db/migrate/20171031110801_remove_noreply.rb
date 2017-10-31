# frozen_string_literal: true
class RemoveNoreply < ActiveRecord::Migration[5.1]
  class User < ActiveRecord::Base
  end

  def up
    User.where(User.arel_table[:email].matches("noreply%")).where(integration: true).update(email: nil)
  end

  def down
  end
end
