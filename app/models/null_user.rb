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
    user&.name || 'Deleted User'
  end

  def email
    "deleted-user-#{id}"
  end

  def marked_for_destruction?
    false
  end

  private

  def user
    return @user if defined?(@user)
    @user = User.with_deleted { User.find_by(id: id) }
  end
end
