# frozen_string_literal: true
module SamsonAirbrakeHook
  class SamsonPlugin < Rails::Engine
  end

  class Notification
    class << self
      VALID_RAILS_ENV = /^[a-z]+$/.freeze
      SECRET_KEY = 'airbrake_api_key'

      def deliver_for(deploy)
        return unless DeployGroup.enabled?
        return unless deploy.stage.notify_airbrake
        return unless deploy.succeeded?

        deploy.stage.deploy_groups.group_by(&:environment).each do |environment, deploy_groups|
          rails_env = environment.name.downcase
          next unless rails_env.match?(VALID_RAILS_ENV)

          next unless project_api_key = read_secret(deploy.project, deploy_groups, SECRET_KEY)

          # using v1 deploy api since it does not need the project_id to simplify configuration
          Faraday.post(
            "https://api.airbrake.io/deploys.txt",
            api_key: project_api_key,
            deploy: {
              rails_env: rails_env,
              scm_revision: deploy.job.commit,
              scm_repository: git_to_http(deploy.project.repository_url),
              local_username: deploy.user.name
            }
          )
        end
      end

      private

      # git@foo:bar/baz.git -> https://foo/bar/baz
      # https://foo/bar/baz.git -> https://foo/bar/baz
      def git_to_http(url)
        url = url.sub(/\.git\z/, '')
        url.sub(/.*?@(.*?):/, "https://\\1/")
      end

      def read_secret(project, deploy_groups, key)
        Samson::Secrets::KeyResolver.new(project, deploy_groups).read(key)
      end
    end
  end
end

Samson::Hooks.callback :after_deploy do |deploy, _|
  SamsonAirbrakeHook::Notification.deliver_for(deploy)
end

Samson::Hooks.view :stage_form, 'samson_airbrake_hook'

Samson::Hooks.callback(:stage_permitted_params) { :notify_airbrake }
