# frozen_string_literal: true
class FlowdockNotificationRenderer
  def self.render(deploy)
    lookup_context = ActionView::LookupContext.new([File.expand_path('../views/samson_flowdock', __dir__)])
    view = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)
    locals = {deploy: deploy, changeset: deploy.changeset}
    view.render(template: 'notification', locals: locals).chomp
  end
end
