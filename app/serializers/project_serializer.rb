class ProjectSerializer < ActiveModel::Serializer
  attributes :id, :name, :url

  def url
    project_path(object)
  end
end
