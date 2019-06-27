# frozen_string_literal: true

class RollbarDashboards::DashboardsController < ApplicationController
  NUM_ITEMS = 4

  def project_dashboard
    project = Project.find_by_permalink!(params.require(:project_id))

    dashboard_html = Rails.cache.fetch(['project_dashboard', project], expires_in: 10.minutes) do
      data = project.rollbar_dashboards_settings.map do |setting|
        items = RollbarDashboards::Client.new(setting).top_errors&.first(NUM_ITEMS)
        [setting, items]
      end

      render_to_string(
        partial: 'rollbar_dashboards/dashboard',
        collection: data,
        as: :dashboard_data,
        locals: {title: "Top #{NUM_ITEMS} Items in the Last 24 Hours"}
      )
    end

    render plain: dashboard_html
  end

  def deploy_dashboard
    deploy = Deploy.find(params.require(:deploy_id))

    dashboard_html = Rails.cache.fetch(['deploy_dashboard', deploy], expires_in: 10.minutes) do
      data = deploy.project.rollbar_dashboards_settings.map do |setting|
        client = RollbarDashboards::Client.new(setting)

        rql_job_id = client.create_rql_job(deploy_rql_query(deploy))
        items = rql_job_id ? client.rql_job_result(rql_job_id) : nil
        [setting, items]
      end

      render_to_string(
        partial: 'rollbar_dashboards/dashboard',
        collection: data,
        as: :dashboard_data,
        locals: {title: "Top #{NUM_ITEMS} Items That Occurred This Deploy"}
      )
    end

    render plain: dashboard_html
  end

  private

  def deploy_rql_query(deploy)
    environment = deploy.stage.deploy_groups.first.environment.name.downcase
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
