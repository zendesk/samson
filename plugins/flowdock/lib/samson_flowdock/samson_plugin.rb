module SamsonFlowdock
  class Engine < Rails::Engine
    config.autoload_paths += Dir["#{config.root}/lib/**/"]
  end
end

Samson::Hooks.callback :stage_defined do
  Stage.class_eval do
    has_many :flowdock_flows

    accepts_nested_attributes_for :flowdock_flows, allow_destroy: true, reject_if: :no_flowdock_token?

    def send_flowdock_notifications?
      flowdock_flows.enabled.any?
    end

    def flowdock_tokens
      flowdock_flows.map(&:token)
    end

    def no_flowdock_token?(flowdock_attrs)
      flowdock_attrs['token'].blank?
    end

    def enabled_flows_names
      flowdock_flows.enabled.map(&:name)
    end
  end
end

Samson::Hooks.callback :deploy_defined do
  Deploy.class_eval do

    def default_flowdock_message(user)
      deploy_url = url_helpers.project_deploy_url(self.stage.project, self)
      ":pray: #{user_tag(user)} is requesting approval for deploy #{deploy_url}"
    end

    private

    def user_tag(user)
      "@#{user.email.match(/(.*)@/)[1]}"
    end

    def url_helpers
      Rails.application.routes.url_helpers
    end
  end
end

Samson::Hooks.view :stage_form, "samson_flowdock/fields"
Samson::Hooks.view :deploy_shown, 'samson_flowdock/notify_buddy_box'

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.flowdock_flows.build(old_stage.flowdock_flows.map(&:attributes))
end

Samson::Hooks.callback :stage_permitted_params do
  { flowdock_flows_attributes: [:id, :name, :token, :_destroy, :enabled] }
end

notify = -> (stage, deploy, _buddy) do
  if stage.send_flowdock_notifications?
    FlowdockNotification.new(deploy).deliver
  end
end

Samson::Hooks.callback :before_deploy, &notify
Samson::Hooks.callback :after_deploy, &notify
