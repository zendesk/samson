# frozen_string_literal: true
class SecretSharingGrant < ActiveRecord::Base
  has_paper_trail skip: [:created_at]
  belongs_to :project
  validates :key, uniqueness: { scope: :project }
end
