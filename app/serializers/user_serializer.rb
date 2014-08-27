class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :role_id, :gravatar_url

  def gravatar_url
    object.gravatar_url
  end
end
