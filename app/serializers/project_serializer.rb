# frozen_string_literal: true
class ProjectSerializer < ActiveModel::Serializer
  attributes :id, :name, :url, :permalink, :repository_url, :owner, :created_at

  def self.csv_header
    ['ID', 'Name', 'URL', 'Permalink', 'Repository URL', 'Owner', 'Created At']
  end

  def url
    Rails.application.routes.url_helpers.project_url(object)
  end

  def csv_line
    to_h.values
  end
end
