class NullUser

  include ActiveModel::Serialization

  attr_accessor :name, :id

  def initialize (uid=0)
    self.id = uid
  end

  def attributes
    {'name' => name}
  end

  def name
    User.with_deleted do
      begin
        u = User.find(id)
        u ?  u.name : 'Deleted User'
      rescue ActiveRecord::RecordNotFound => e
        u = 'Deleted User'
      end
    end
  end

end
