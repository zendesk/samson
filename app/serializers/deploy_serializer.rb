class DeploySerializer < ActiveModel::Serializer
  include ApplicationHelper
  include ActionView::Helpers::DateHelper

  attributes :id, :updated_at, :summary, :url, :production, :status

  has_one :project
  has_one :user

  def url
    project_deploy_url(object.project, object)
  end

  def summary
    object.summary_for_timeline
  end

  def updated_at
    datetime_to_js_ms(object.updated_at)
  end
end
