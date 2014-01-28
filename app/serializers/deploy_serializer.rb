class DeploySerializer < ActiveModel::Serializer
  attributes :updated_at, :summary
  has_one :project

  def updated_at
    object.updated_at.strftime("%H:%M %m/%d/%Y")
  end
end
