# frozen_string_literal: true
class EnvironmentSerializer < ActiveModel::Serializer
  attributes :id, :name, :permalink, :production, :created_at, :updated_at, :deleted_at

  has_many :deploy_groups
end
