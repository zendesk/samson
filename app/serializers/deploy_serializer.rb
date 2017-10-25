# frozen_string_literal: true
class DeploySerializer < ActiveModel::Serializer
  attributes :id, :updated_at, :summary, :url, :production, :status

  has_one :project
  has_one :stage
  has_one :user

  def summary
    object.summary_for_timeline
  end
end
