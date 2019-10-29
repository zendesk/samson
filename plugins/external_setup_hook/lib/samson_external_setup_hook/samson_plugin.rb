module SamsonExternalSetupHook
  class Engine < Rails::Engine
  end

  POLL_INTERVAL = 15
  POLL_WAIT_TIME = 30
  TRIGGER_WAIT_TIME = 30

  def self.wait_for_external_setup(job, output, stage, ctx_data)
    status_poll_url = nil
    success = false

    setup_hook = stage.external_setup_hook

    return true if setup_hook.nil?

    output.write("Trigger external setup through #{setup_hook.endpoint}\n")

    trigger_wait_time = TRIGGER_WAIT_TIME
    until trigger_wait_time < 0 do
      trigger_wait_time -= POLL_INTERVAL

      response = Faraday.post(setup_hook.endpoint, ctx_data.to_json) do |req|
        req.options.timeout = req.options.open_timeout = 5
        req.headers['Content-Type'] = 'application/json'

        if setup_hook.auth_type == "token"
          req.headers['Authorization'] = "token #{setup_hook.auth_token}"
        end
      end
      if response.status == 200
        body = JSON.parse response.body
        status_poll_url = body['status_poll_url'] || nil
      end

      break unless status_poll_url.nil?
      sleep POLL_INTERVAL
    end

    return false if status_poll_url.nil?

    output.write("Polling external setup status through #{status_poll_url}\n")

    poll_wait_time = POLL_WAIT_TIME
    until poll_wait_time < 0 do
      poll_wait_time -= POLL_INTERVAL

      response = Faraday.get(status_poll_url) do |req|
        req.options.timeout = req.options.open_timeout = 5
      end
      if response.status == 200
        body = JSON.parse response.body
        success = (body['status'] == 'success')
      end

      break if success
      sleep POLL_INTERVAL
    end

    return success
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
    {stage_external_setup_hook_attributes: [:external_setup_hook_id]}
  ]
end

Samson::Hooks.callback :before_deploy_setup do |job, output, stage, ctx_data|
  SamsonExternalSetupHook.wait_for_external_setup(job, output, stage, ctx_data)
end
