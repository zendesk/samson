# frozen_string_literal: true

module SamsonAssertible
  class SamsonPlugin < Rails::Engine
  end

  class Notification
    class << self
      def deliver(deploy)
        return unless deploy.stage.notify_assertible? && deploy.succeeded?

        conn = Faraday.new(url: 'https://assertible.com')
        conn.request :authorization, :basic, deploy_token, ''
        conn.post(
          '/deployments',
          {
            service: service_key,
            environmentName: deploy.stage.name,
            version: 'v1',
            url: url_helpers.project_deploy_url(
              id: deploy.id,
              project_id: deploy.project.id
            )
          }.to_json
        )
      end

      private

      def service_key
        ENV.fetch('ASSERTIBLE_SERVICE_KEY')
      end

      def deploy_token
        ENV.fetch('ASSERTIBLE_DEPLOY_TOKEN')
      end

      def url_helpers
        Rails.application.routes.url_helpers
      end
    end
  end
end

Samson::Hooks.view :stage_form_checkbox, 'samson_assertible'

Samson::Hooks.callback :after_deploy do |deploy, _|
  SamsonAssertible::Notification.deliver(deploy)
end

Samson::Hooks.callback :stage_permitted_params do
  :notify_assertible
end
