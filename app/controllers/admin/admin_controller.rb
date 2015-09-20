class Admin::AdminController < ApplicationController
  before_action :authorize_admin!

  def project_roles
    render json: ProjectRole.all.map { |role| { id: role.id, display_name: role.display_name } }, root: false
  end
end