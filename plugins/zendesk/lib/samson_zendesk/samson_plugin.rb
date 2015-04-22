module SamsonZendesk
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_zendesk/fields"

Samson::Hooks.callback :stage_permitted_params do
  :comment_on_zendesk_tickets
end

Samson::Hooks.callback :after_deploy do |deploy, _buddy|
  if deploy.stage.comment_on_zendesk_tickets?
    ZendeskNotification.new(deploy).deliver
  end
end

if Rails.env.test?
  ENV['ZENDESK_URL'] = 'https://test.support.zendesk'
  ENV['ZENDESK_TOKEN'] = 'c30398e3275532c5602bdf00cb153b806c000e4e46fac2f3acc0783822b8f6d3'
end
