# frozen_string_literal: true
class ExternalEnvironmentVariableGroupsController < ApplicationController
  def preview
    @group = ExternalEnvironmentVariableGroup.find(params[:id])
    @data = @group.read

    respond_to do |format|
      format.html
      format.json { render json: {group: @group, data: @data} }
    end
  end
end
