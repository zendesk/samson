# frozen_string_literal: true
class ReleasesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!, except: [:show, :index]

  def show
    @release = @project.releases.find_by_param!(params[:id])
    @changeset = @release.changeset
    render 'row_content', layout: false if request.xhr?
  end

  def index
    @stages = @project.stages
    @pagy, @releases = pagy(@project.releases.order(id: :desc), page: params[:page], items: 15)
  end

  def new
    @release = Release.new(project: @project)
    @release.assign_release_number
  end

  def create
    @release = ReleaseService.new(@project).release(release_params)
    if @release.persisted?
      redirect_to [@project, @release]
    else
      flash[:alert] = @release.errors.full_messages.to_sentence
      render action: :new
    end
  end

  private

  def release_params
    params.require(:release).permit(:commit, :number).merge(author: current_user)
  end
end
