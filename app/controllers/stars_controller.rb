# frozen_string_literal: true
class StarsController < ApplicationController
  include CurrentProject

  # toggles star by creating/destroying it
  def create
    if star = current_user.stars.find_by_project_id(current_project.id)
      star&.destroy
    else
      current_user.stars.create!(project: current_project)
    end

    head :ok
  end
end
