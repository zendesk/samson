# frozen_string_literal: true
class Kubernetes::ReleasesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!

  def index
    @pagy, @kubernetes_releases = pagy(current_project.kubernetes_releases.order('id desc'), items: 25)
  end

  def show
    @kubernetes_release = current_project.kubernetes_releases.find(params.require(:id))
  end
end
