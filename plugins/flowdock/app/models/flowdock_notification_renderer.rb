# frozen_string_literal: true
class FlowdockNotificationRenderer
  def self.render(deploy)
    controller = ActionController::Base.new
    view = ActionView::Base.new(File.expand_path('../views/samson_flowdock', __dir__), {}, controller)
    locals = {deploy: deploy, changeset: deploy.changeset}
    view.render(template: 'notification', locals: locals).chomp
  end
end
