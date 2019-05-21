# frozen_string_literal: true
class Kubernetes::RoleVerificationsController < ApplicationController
  def new
  end

  def create
    input = params[:role].presence || '{}'
    filename = (input.start_with?('{', '[') ? 'test.json' : 'test.yml')
    begin
      Kubernetes::RoleConfigFile.new(input, filename, project: nil)
    rescue Samson::Hooks::UserError
      @errors = $!.message
    else
      flash.now[:notice] = "Valid!"
    end
    render :new
  end
end
