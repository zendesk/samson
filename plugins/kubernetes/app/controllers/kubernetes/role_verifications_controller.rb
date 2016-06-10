class Kubernetes::RoleVerificationsController < ApplicationController
  def new
  end

  def create
    input = params[:role].presence || '{}'
    unless @errors = Kubernetes::RoleVerifier.new(input).verify
      flash.now[:notice] = "Valid!"
    end
    render :new
  end
end
