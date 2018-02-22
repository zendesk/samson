# frozen_string_literal: true

class GkeCluster
  include ActiveModel::Model

  attr_accessor(
    :gcp_project,
    :cluster_name,
    :zone
  )

  validates :gcp_project, presence: true
  validates :cluster_name, presence: true
  validates :zone, presence: true
end
