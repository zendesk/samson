# frozen_string_literal: true
class RemoveInvalidUsers < ActiveRecord::Migration[5.0]
  class User < ActiveRecord::Base
  end

  def change
    User.where(deleted_at: nil, external_id: nil, integration: false).update_all(deleted_at: Time.at(1478211603))
  end
end
