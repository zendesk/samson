# frozen_string_literal: true
class Kubernetes::ReleasesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!

  def index
    @kubernetes_releases = current_project.kubernetes_releases.order('id desc')
  end

  def show
    @kubernetes_release = current_project.kubernetes_releases.find(params.require(:id))
  end
end
