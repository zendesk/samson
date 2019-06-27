# frozen_string_literal: true
class ReferencesController < ApplicationController
  include CurrentProject
  CACHE_TTL = Integer(ENV['REFERENCES_CACHE_TTL'].presence || 10.minutes.to_s)

  before_action :authorize_project_deployer!

  def index
    references = Rails.cache.fetch("#{@project.id}_git_references", expires_in: CACHE_TTL) do
      repository = @project.repository
      (repository.branches + repository.tags).sort_by! { |ref| [-ref.length, ref] }.reverse!
    end
    render json: references, root: false
  end
end
