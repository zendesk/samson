# frozen_string_literal: true
require 'csv'

class ProjectsController < ResourceController
  before_action :set_resource, only: [:show, :edit, :update, :destroy, :deploy_group_versions, :new, :create]
  before_action :authorize_resource!, except: [:deploy_group_versions, :edit]

  # TODO: make this behave more like resource_controller
  def index
    projects = projects_for_user

    respond_to do |format|
      format.html do
        if params[:partial] == "nav"
          @projects = projects
          render partial: "projects/nav", layout: false
        else
          per_page = 9 # 3 or 1 column layout depending on size
          # Workaround with pagy internals for https://github.com/rails/rails/issues/33719
          count = projects.reorder(nil).count(:all) # count on joined query with ordering does not work
          count = count.count if count.is_a?(Hash) # fix for AR grouping count inconsistency (Hash instead of Integer)
          @pagy = Pagy.new(count: count, page: page, items: per_page)
          @projects = pagy_get_items(projects, @pagy)
        end
      end

      format.json do
        render json: {projects: projects_as_json(projects)}
      end

      format.csv do
        datetime = Time.now.strftime "%Y-%m-%d_%H-%M"
        send_data projects_as_csv(projects), type: :csv, filename: "Projects_#{datetime}.csv"
      end
    end
  end

  def new
    super
    @project.stages.build(name: "Production")
  end

  def deploy_group_versions
    before = params[:before] ? Time.parse(params[:before]) : Time.now
    deploy_group_versions = @project.last_deploy_by_group(before).each_with_object({}) do |(id, deploy), hash|
      hash[id] = deploy.as_json
    end
    render json: deploy_group_versions
  end

  protected

  # compatibility with authorize_resource!
  def current_project
    @project
  end

  def create_callback
    if to = created_email
      ProjectMailer.created_email(to, current_user, @project).deliver_now
    end
  end

  def destroy_callback
    if to = (ENV["PROJECT_DELETED_NOTIFY_ADDRESS"] || created_email)
      ProjectMailer.deleted_email(to, current_user, @project).deliver_now
    end
  end

  def created_email
    ENV["PROJECT_CREATED_NOTIFY_ADDRESS"]
  end

  def allowed_includes
    [
      :environment_variable_groups,
      :environment_variables_with_scope,
    ]
  end

  def resource_params
    super.permit(
      *[
        :name,
        :repository_url,
        :description,
        :owner,
        :permalink,
        :release_branch,
        :release_source,
        :docker_release_branch,
        :dockerfiles,
        :docker_build_method,
        :include_new_deploy_groups,
        :dashboard,
      ] + Samson::Hooks.fire(:project_permitted_params)
    ).merge(current_user: current_user)
  end

  # TODO: rename ... not user anymore
  def projects_for_user
    scope =
      if search = params.dig(:search).presence
        scope = Project
        if query = search[:query]
          scope = scope.search(query)
        end
        if url = search[:url]
          # users can pass in git@ or https:// with or without .git
          # database has git@ or https:// urls with .git
          uri = URI.parse(url.sub(/\.git$/, '').sub(':', '/').sub('git@', 'https://'))
          git = "git@#{uri.host}#{uri.path.sub('/', ':')}.git"
          urls = [
            url, # make sure the exact query always matches
            git,
            "ssh://#{git}",
            "https://#{uri.host}#{uri.path}.git"
          ]
          scope = scope.where(repository_url: urls)
        end
        scope
      else
        Project.ordered_for_user(current_user) # TODO: wasteful to use join when just doing counts
      end
    scope.alphabetical.order(id: :desc)
  end

  # Avoiding N+1 queries on project index
  def last_deploy_for(project)
    @projects_last_deployed_at ||= Deploy.successful.
      last_deploys_for_projects.
      includes(:project, job: :user).
      index_by(&:project_id)

    @projects_last_deployed_at[project.id]
  end

  def projects_as_json(projects)
    projects.map do |project|
      json = project.as_json
      last_deploy = last_deploy_for(project)
      json['last_deployed_at'] = last_deploy&.created_at
      json['last_deployed_by'] = last_deploy&.user&.email
      json['last_deploy_url'] = last_deploy&.url
      json
    end
  end

  def projects_as_csv(projects)
    attributes = [:id, :name, :url, :permalink, :repository_url, :owner, :created_at].freeze
    CSV.generate do |csv|
      header = attributes.map { |a| a.to_s.humanize }
      header << 'Last Deploy At'
      header << 'Last Deploy By'
      header << 'Last Deploy URL'
      csv << header

      projects.each do |project|
        line = attributes.map { |a| project.public_send(a) }
        last_deploy = last_deploy_for(project)
        line << last_deploy&.created_at
        line << last_deploy&.user&.email
        line << last_deploy&.url
        csv << line
      end
    end
  end
end
