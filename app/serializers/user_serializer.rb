class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :gravatar_url

  def gravatar_url
    object.avatar_url
  end
end
