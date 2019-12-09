# frozen_string_literal: true
class SecretSharingGrant < ActiveRecord::Base
  audited
  belongs_to :project, inverse_of: :secret_sharing_grants
  validates :key,
    uniqueness: {scope: :project_id, message: "and project combination already in use", case_sensitive: true}
end
Samson::Hooks.load_decorators(SecretSharingGrant)
