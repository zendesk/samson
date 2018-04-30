# frozen_string_literal: true
class ZendeskNotificationRenderer
  class << self
    def render(deploy, ticket_id)
      controller = ActionController::Base.new
      view = ActionView::Base.new(File.expand_path('../views/samson_zendesk', __dir__), {}, controller)
      locals = {deploy: deploy, commits: deploy.changeset.commits, ticket_id: ticket_id, url: url(deploy)}
      view.render(template: 'notification', locals: locals).chomp
    end

    private

    def url(deploy)
      Rails.application.routes.url_helpers.project_deploy_url(deploy.project, deploy)
    end
  end
end
