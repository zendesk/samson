class StatsController < ApplicationController

  def projects
    respond_to do |format|
      format.json { render json: Project.get_stats }
    end
  end

end
