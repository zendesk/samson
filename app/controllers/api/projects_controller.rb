# frozen_string_literal: true
class Api::ProjectsController < Api::BaseController
  def index
    render json: Project.ordered_for_user(current_user).all
  end
end
