class FlowdockNotificationRenderer
  def self.render(deploy)
    controller = ActionController::Base.new
    view = ActionView::Base.new('app/views/flowdock', {}, controller)
    locals = { deploy: deploy, changeset: deploy.changeset }
    view.render(template: 'notification', locals: locals).chomp
  end
end
