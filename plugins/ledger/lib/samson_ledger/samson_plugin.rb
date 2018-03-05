# frozen_string_literal: true
module SamsonLedger
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :before_deploy do |deploy|
  SamsonLedger::Client.post_deployment(deploy)
end

Samson::Hooks.callback :after_deploy do |deploy|
  SamsonLedger::Client.post_deployment(deploy)
end
