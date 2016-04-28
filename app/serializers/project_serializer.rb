class ProjectSerializer < ActiveModel::Serializer
  attributes :id, :name, :url

  def url
    project_url(object)
  end
end
