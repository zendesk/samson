# frozen_string_literal: true
class LockSerializer < ActiveModel::Serializer
  attributes :id, :resource_id, :resource_type, :warning, :user_id, :created_at
end
