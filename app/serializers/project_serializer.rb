# frozen_string_literal: true
class ProjectSerializer < ActiveModel::Serializer
  attributes :id, :name, :url, :permalink, :repository_url

  def url
    project_url(object)
  end
end
