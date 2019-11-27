# frozen_string_literal: true

class RollbarDashboards::DashboardsController < ApplicationController
  NUM_ITEMS = 4
  EXPIRES_IN = 1.minute

  def project_dashboard
    project = Project.find_by_permalink!(params.require(:project_id))
    dashboard_html = Rails.cache.fetch(['project_dashboard', project], expires_in: EXPIRES_IN) do
      environment = "production"
      hours = 24
      data = project.rollbar_dashboards_settings.map do |setting|
        items = RollbarDashboards::Client.new(setting).top_errors(
          hours: hours, environments: [environment]
        )&.first(NUM_ITEMS)
        [setting, items]
      end

      dashboard_to_string "Top #{NUM_ITEMS} Items in #{environment} in the Last #{hours} Hours", data
    end
    render plain: dashboard_html
  rescue Samson::Hooks::UserError => e
    render plain: e.message
  end

  def deploy_dashboard
    deploy = Deploy.find(params.require(:deploy_id))

    dashboard_html = Rails.cache.fetch(['deploy_dashboard', deploy], expires_in: EXPIRES_IN) do
      environment = deploy.stage.deploy_groups.first.environment.name.downcase
      data = deploy.project.rollbar_dashboards_settings.map do |setting|
        client = RollbarDashboards::Client.new(setting)
        rql_job_id = client.create_rql_job(deploy_rql_query(deploy, environment))
        [setting, client.rql_job_result(rql_job_id)]
      end

      dashboard_to_string "Top #{NUM_ITEMS} Items in #{environment} For This Deploy", data
    end

    render plain: dashboard_html
  rescue Samson::Hooks::UserError => e
    render plain: e.message
  end

  private

  def dashboard_to_string(title, data)
    render_to_string(
      partial: 'rollbar_dashboards/dashboard',
      collection: data,
      as: :dashboard_data,
      locals: {title: title}
    )
  end

  def deploy_rql_query(deploy, environment)
    next_succeeded_deploy = deploy.next_succeeded_deploy

    timestamp_query = if next_succeeded_deploy
      "timestamp BETWEEN #{deploy.created_at.to_i} and #{next_succeeded_deploy.created_at.to_i}"
    else
      "timestamp >= #{deploy.created_at.to_i}"
    end

    <<~RQL.squish
      SELECT timestamp DIV 86400 as t,
             item.counter as counter,
             item.title as title,
             Count(*) as occurrences,
             item.environment as environment
      FROM   item_occurrence
      WHERE  environment = "#{environment}"
             AND #{timestamp_query}
      GROUP  BY 1,
                item.counter
      ORDER  BY 4 DESC
      LIMIT  #{NUM_ITEMS}
    RQL
  end
end
