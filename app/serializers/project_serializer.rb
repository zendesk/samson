# frozen_string_literal: true
class ProjectSerializer < ActiveModel::Serializer
  PROPERTIES = [:id, :name, :url, :permalink, :repository_url, :owner, :created_at].freeze
  attributes *PROPERTIES

  def self.csv_header
    PROPERTIES.map { |p| p.to_s.humanize }
  end

  def url
    Rails.application.routes.url_helpers.project_url(object)
  end

  def csv_line
    PROPERTIES.map { |p| object.public_send p }
  end
end
