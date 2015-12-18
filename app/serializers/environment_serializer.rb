class EnvironmentSerializer < ActiveModel::Serializer
  attributes :id, :name, :permalink, :is_production, :created_at, :updated_at, :deleted_at

  has_many :deploy_groups
end
