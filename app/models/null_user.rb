class NullUser

  include ActiveModel::Serialization

  attr_accessor :name, :id

  def initialize(uid=0)
    self.id = uid
  end

  def attributes
    {'name' => name}
  end

  def user
    return @user if defined?(@user)
    @user = User.with_deleted { User.where(id: id).first }
  end

  def name
    user.try(:name) || 'Deleted User'
  end

end
