module SamsonExternalSetupHook
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :manage_menu, 'samson_external_setup_hook'

Samson::Hooks.view :stage_form, 'samson_external_setup_hook'

Samson::Hooks.callback :link_parts_for_resource do
  [
    "ExternalSetupHook",
    ->(hook) { [hook.name, hook] }
  ]
end

Samson::Hooks.callback :stage_permitted_params do
  [
    :external_setup_hook_id,
  ]
end
