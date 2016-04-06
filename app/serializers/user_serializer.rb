class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :role_id, :gravatar_url, :time_format

  def gravatar_url
    object.gravatar_url
  end
end
