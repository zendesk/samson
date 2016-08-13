# frozen_string_literal: true
class Star < ActiveRecord::Base
  belongs_to :user
  belongs_to :project

  after_create :expire_user_cache
  after_destroy :expire_user_cache

  private

  def expire_user_cache
    Rails.cache.delete([:starred_projects_ids, user_id])
  end
end
