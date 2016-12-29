# frozen_string_literal: true
module SamsonNewRelic
  class Engine < Rails::Engine
  end

  KEY = ENV['NEWRELIC_API_KEY'].presence

  def self.enabled?
    KEY
  end
end

Samson::Hooks.view :stage_form, "samson_new_relic/fields"
Samson::Hooks.view :deploy_tab_nav, "samson_new_relic/deploy_tab_nav"
Samson::Hooks.view :deploy_tab_body, "samson_new_relic/deploy_tab_body"

Samson::Hooks.callback :stage_permitted_params do
  {new_relic_applications_attributes: [:id, :name, :_destroy]}
end

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  old_applications = old_stage.new_relic_applications.map do |app|
    app.attributes.except("id", "updated_at", "created_at")
  end
  new_stage.new_relic_applications.build(old_applications)
end
