# frozen_string_literal: true
module SamsonFlowdock
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_flowdock"
Samson::Hooks.view :deploy_view, "samson_flowdock"

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.flowdock_flows.build(
    old_stage.flowdock_flows.map { |f| f.attributes.except("id", "created_at", "updated_at") }
  )
end

Samson::Hooks.callback :stage_permitted_params do
  {flowdock_flows_attributes: [:id, :name, :token, :_destroy]}
end

notify = ->(deploy, _) do
  if deploy.stage.send_flowdock_notifications?
    FlowdockNotification.new(deploy).deliver
  end
end

Samson::Hooks.callback :before_deploy, &notify
Samson::Hooks.callback :after_deploy, &notify
