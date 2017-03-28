# frozen_string_literal: true
class ChangelogsController < ApplicationController
  include CurrentProject

  def show
    if params[:start_date].blank? || params[:end_date].blank?
      params[:start_date] = (Date.today.beginning_of_week - 3.days).to_s
      params[:end_date] = Date.today.to_s
    end

    @start_date = Date.strptime(params[:start_date], '%Y-%m-%d')
    @end_date = Date.strptime(params[:end_date], '%Y-%m-%d')

    @changeset = Changeset.new(current_project.github_repo, "master@{#{@start_date}}", "master@{#{@end_date}}")
  end

  def deploy_check
    commit = params.require(:commit)
    stage = Stage.find(params.require(:stage_id))


    tag = current_project.git_repository.fuzzy_tag_from_ref(commit).split('-').first
    releases = Release.where(project_id: current_project.id)
    tagged_release = releases.where(number: tag.sub('v', '')).first!
    possible_commits = releases.where('id >= ?', tagged_release.id).pluck(:commit)
    deploy = stage.deploys.where(commit: possible_commits).order('created_at asc').first
    render plain: "Found #{deploy}"
  end
end
