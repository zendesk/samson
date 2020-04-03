# frozen_string_literal: true
class ExternalEnvironmentVariableGroupsController < ApplicationController
  def preview
    @group =
      if params.require(:id) == "fake"
        ExternalEnvironmentVariableGroup.new(
          project: Project.new,
          name: "Preview",
          url: params.require(:url)
        )
      else
        ExternalEnvironmentVariableGroup.find(params[:id])
      end

    @data = @group.read

    respond_to do |format|
      format.html
      format.json { render json: {group: @group, data: @data} }
    end
  end
end
