# frozen_string_literal: true
class BuildSerializer < ActiveModel::Serializer
  include DateTimeHelper

  attributes :id, :label, :git_sha, :git_ref, :docker_image_id, :docker_tag,
    :docker_repo_digest, :docker_status, :created_at

  has_one :project

  def created_at
    datetime_to_js_ms(object.created_at)
  end
end
