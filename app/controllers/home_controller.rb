# frozen_string_literal: true
require 'csv'

class HomeController < ApplicationController
  include CurrentProject

  def index
    @deploys =
      if ids = params[:ids]
        Kaminari.paginate_array(deploys_scope.find(ids)).page(1).per(1000)
      else
        search || return
      end

    respond_to do |format|
      format.json do
        render_as_json :deploys, @deploys, allowed_includes: [:job, :project, :user, :stage]
      end
      format.csv do
        datetime = Time.now.strftime "%Y%m%d_%H%M"
        send_data as_csv, type: :csv, filename: "Deploys_search_#{datetime}.csv"
      end
      format.html
    end
  end

  def search
    search = params[:search] || {}
    status = (search[:status] || search[:filter]).presence # :filter is deprecated
    git_sha = search[:git_sha].presence

    if status && !Job.valid_status?(status)
      render_json_error 400, "invalid status given"
      return
    end

    if deployer = search[:deployer].presence
      users = User.where(
        User.arel_table[:name].matches("%#{ActiveRecord::Base.send(:sanitize_sql_like, deployer)}%")
      ).pluck(:id)
    end

    if project_name = search[:project_name].presence
      projects = Project.where(
        Project.arel_table[:name].matches("%#{ActiveRecord::Base.send(:sanitize_sql_like, project_name)}%")
      ).pluck(:id)
    end

    if users || status || git_sha
      jobs = Job
      jobs = jobs.where(user: users) if users
      jobs = jobs.where(status: status) if status
      jobs = jobs.where(commit: git_sha) if git_sha # previously jobs only stored short shas
    end

    production = search[:production].presence
    code_deployed = search[:code_deployed].presence
    group = search[:group].presence
    if group || projects || !code_deployed.nil? || !production.nil?
      stages = Stage
      if group
        stages = stages.where(id: stage_ids_for_group(group))
      end
      if projects
        stages = stages.where(project: projects)
      end
      unless code_deployed.nil?
        stages = stages.where(no_code_deployed: param_to_bool(code_deployed))
      end
      unless production.nil?
        production = param_to_bool(production)
        stages = stages.select { |stage| stage.production? == production }
      end
    end

    deploys = deploys_scope
    deploys = deploys.where(stage: stages) if stages
    deploys = deploys.where(job: jobs) if jobs
    if updated_at = search[:updated_at].presence
      deploys = deploys.where("updated_at between ? AND ?", *updated_at)
    end
    deploys.page(page).per(30)
  end

  def deploys_scope
    current_project&.deploys || Deploy
  end
end
