# frozen_string_literal: true
class ExternalEnvironmentVariableGroupsController < ApplicationController
  def preview
    @group = ExternalEnvironmentVariableGroup.find(params[:id])
    @data = @group.external_service_read_with_failover

    respond_to do |format|
      format.html
      format.json { render json: {group: @group, data: @data} }
    end
  end
end
