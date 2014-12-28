class ZendeskNotificationRenderer
  def self.render(deploy, ticket_id)
    controller = ActionController::Base.new
    view = ActionView::Base.new('app/views/zendesk', {}, controller)
    locals = { deploy: deploy, commits: deploy.changeset.commits, ticket_id: ticket_id, url: url(deploy) }
    view.render(template: 'notification', locals: locals).chomp
  end

  private

  def self.url(deploy)
    Rails.application.routes.url_helpers.project_deploy_url(deploy.project, deploy)
  end
end
