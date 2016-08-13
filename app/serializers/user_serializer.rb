# frozen_string_literal: true
class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :role_id, :gravatar_url, :time_format
end
