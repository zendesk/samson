# frozen_string_literal: true
class SlackWebhookNotificationRenderer
  def self.render(deploy, subject)
    controller = ActionController::Base.new
    view = ActionView::Base.new(File.expand_path("../../views/samson_slack_webhooks", __FILE__), {}, controller)
    locals = { deploy: deploy, changeset: deploy.changeset, subject: subject }
    view.render(template: 'notification', locals: locals).chomp
  end
end
