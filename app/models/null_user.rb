# frozen_string_literal: true
class NullUser
  include ActiveModel::Serialization

  attr_accessor :id
  attr_writer :name

  def initialize(id)
    self.id = id
  end

  def attributes
    {'name' => name}
  end

  def name
    user.try(:name) || 'Deleted User'
  end

  private

  def user
    return @user if defined?(@user)
    @user = User.with_deleted { User.where(id: id).first }
  end
end
