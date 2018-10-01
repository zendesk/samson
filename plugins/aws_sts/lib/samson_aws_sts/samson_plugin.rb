module SamsonAwsSts
  class Engine < Rails::Engine
  end

  class << self
    def set_env_vars(deploy)
      # if deploy.stage.send_datadog_notifications?
      #   DatadogNotification.new(deploy).deliver(**kwargs)
      # end
    end
  end
end

Samson::Hooks.view :stage_form, 'samson_aws_sts/fields'

Samson::Hooks.callback :stage_permitted_params do
  [
    :aws_sts_iam_role_arn
  ]
end

Samson::Hooks.callback :before_deploy do |deploy, _buddy|
  SamsonAwsSts.set_env_vars(deploy)
end
