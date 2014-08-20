class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :role_id, :role, :gravatar_url

  def role
    Role.find(object.role_id).name
  end
  def gravatar_url
    object.gravatar_url
  end
end
