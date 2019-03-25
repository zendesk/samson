# frozen_string_literal: true
class SlackIdentifier < ActiveRecord::Base
  belongs_to :user, optional: true, inverse_of: nil

  def self.app_token
    SlackIdentifier.find_by_user_id(nil)&.identifier
  end
end
