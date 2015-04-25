module SamsonServerLogs
  class Engine < Rails::Engine
  end
end
Samson::Hooks.view :stage_form, "samson_server_logs/fields"
