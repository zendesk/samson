module SamsonFlowdock
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_flowdock/fields"
Samson::Hooks.view :deploy_view, 'samson_flowdock/notify_buddy_box'

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.flowdock_flows.build(old_stage.flowdock_flows.map(&:attributes))
end

Samson::Hooks.callback :stage_permitted_params do
  { flowdock_flows_attributes: [:id, :name, :token, :_destroy, :enabled] }
end

notify = -> (deploy, _buddy) do
  if deploy.stage.send_flowdock_notifications?
    FlowdockNotification.new(deploy).deliver
  end
end

Samson::Hooks.callback :before_deploy, &notify
Samson::Hooks.callback :after_deploy, &notify
