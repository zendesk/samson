class BuildSerializer < ActiveModel::Serializer
  attributes :id, :git_sha, :git_ref, :docker_sha, :docker_ref, :created_at

  has_one :project

  def created_at
    datetime_to_js_ms(object.created_at)
  end
end
