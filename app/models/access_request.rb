# frozen_string_literal: true

class AccessRequest
  include ActiveModel::Model

  attr_accessor(
    :manager_email,
    :reason,
    :project_ids,
    :role_id
  )

  validates :manager_email, presence: true
  validates :reason, presence: true
  validates :project_ids, presence: true
  validates :role_id, presence: true
end
