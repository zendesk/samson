class NullUser

  include ActiveModel::Serialization

  attr_accessor :name

  def attributes
        {'name' => 'Deleted User'}
  end

  def name
    'Deleted User'
  end

end
