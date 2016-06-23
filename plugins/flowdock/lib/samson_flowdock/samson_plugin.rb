module SamsonFlowdock
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_flowdock/fields"
Samson::Hooks.view :deploy_view, "shared/notify_buddy_box" do |deploy:, project:|
  {
    deploy: deploy, project: project,
    id_prefix: 'flowdock',
    send_buddy_request: deploy.stage.send_flowdock_notifications?,
    form_path: AppRoutes.url_helpers.flowdock_notify_path(deploy_id: deploy.id),
    title: 'Request a buddy via Flowdock',
    message: FlowdockNotification.new(deploy).default_buddy_request_message,
    channels: deploy.stage.enabled_flows_names.join(', '),
    users: SamsonFlowdock::FlowdockService.new(deploy).users,
    channel_type: 'flows'
  }
end

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.flowdock_flows.build(
    old_stage.flowdock_flows.map { |f| f.attributes.except("id", "created_at", "updated_at") }
  )
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
