# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe SamsonRollbarDashboards do
  describe 'project_permitted_params callback' do
    it 'adds rollbar_read_token to permitted params' do
      expected = [
        {rollbar_dashboards_settings_attributes: [:id, :base_url, :read_token, :account_and_project_name, :_destroy]}
      ]

      Samson::Hooks.only_callbacks_for_plugin('rollbar_dashboards', :project_permitted_params) do
        Samson::Hooks.fire(:project_permitted_params).must_equal expected
      end
    end
  end

  describe 'view callbacks' do
    describe 'project_dashboard callback' do
      def render_view(project)
        view_context.instance_variable_set(:@project, project)
        Samson::Hooks.render_views(:project_dashboard, view_context)
      end

      it 'renders nothing if project has no dashboard settings' do
        project = projects(:other)
        project.rollbar_dashboards_settings.must_equal []

        render_view(project).must_equal ''
      end
    end

    describe 'deploy_show_view callback' do
      def render_view(deploy)
        Samson::Hooks.render_views(:deploy_show_view, view_context, deploy: deploy)
      end

      let(:deploy) { deploys(:succeeded_test) }

      it 'renders nothing if the deployment failed' do
        deploy = deploys(:failed_staging_test)

        render_view(deploy).must_equal ''
      end

      it 'renders nothing if project has no dashboard settings' do
        deploy.update_column(:project_id, projects(:other).id)
        deploy.project.rollbar_dashboards_settings.must_equal []

        render_view(deploy).must_equal ''
      end
    end
  end
end
