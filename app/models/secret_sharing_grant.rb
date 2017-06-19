# frozen_string_literal: true
class SecretSharingGrant < ActiveRecord::Base
  audited
  belongs_to :project
  validates :key, uniqueness: {scope: :project_id, message: "and project combination already in use"}
end
