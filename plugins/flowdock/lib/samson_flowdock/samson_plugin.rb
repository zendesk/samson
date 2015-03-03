module SamsonFlowDock
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :stage_defined do
  Stage.class_eval do
    has_many :flowdock_flows

    accepts_nested_attributes_for :flowdock_flows, allow_destroy: true, reject_if: :no_flowdock_token?

    def send_flowdock_notifications?
      flowdock_flows.any?
    end

    def flowdock_tokens
      flowdock_flows.map(&:token)
    end

    def no_flowdock_token?(flowdock_attrs)
      flowdock_attrs['token'].blank?
    end
  end
end

Samson::Hooks.view :stage_form, "samson_flowdock/fields"

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.flowdock_flows.build(old_stage.flowdock_flows.map(&:attributes))
end

Samson::Hooks.callback :stage_permitted_params do
  {flowdock_flows_attributes: [:id, :name, :token, :_destroy]}
end

notify = -> (stage, deploy, _buddy) do
  if stage.send_flowdock_notifications?
    FlowdockNotification.new(stage, deploy).deliver
  end
end

Samson::Hooks.callback :before_deploy, &notify
Samson::Hooks.callback :after_deploy, &notify
