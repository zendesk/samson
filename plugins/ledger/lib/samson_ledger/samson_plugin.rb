# frozen_string_literal: true
module SamsonLedger
  class SamsonPlugin < Rails::Engine
  end
end

callback = ->(deploy, _) do
  SamsonLedger::Client.post_deployment(deploy)
end
Samson::Hooks.callback :before_deploy, &callback
Samson::Hooks.callback :after_deploy, &callback
