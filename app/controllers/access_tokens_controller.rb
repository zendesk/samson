# frozen_string_literal: true
class AccessTokensController < ApplicationController
  def index
    @access_tokens = token_scope
  end

  def new
    @access_token = Doorkeeper::AccessToken.new(scopes: 'default', application: ensure_personal_access_app)
  end

  def create
    token = Doorkeeper::AccessToken.create!(
      params.
        require(:doorkeeper_access_token).
        permit(:description, :scopes, :application_id).
        merge(resource_owner_id: current_user.id)
    )
    redirect_to(
      {action: :index},
      notice: "Token created: copy this token, it will not be shown again: #{token.token}"
    )
  end

  def destroy
    token_scope.find(params.require(:id)).destroy!
    redirect_to(
      {action: :index},
      notice: "Token deleted"
    )
  end

  private

  def token_scope
    Doorkeeper::AccessToken.where(resource_owner_id: current_user.id)
  end

  def ensure_personal_access_app
    Doorkeeper::Application.where(name: 'Personal Access Token').first_or_create!(
      scopes: '', # by default nothing is allowed ... scopes will come from access tokens
      redirect_uri: 'https://example.com' # this app will never redirect
    )
  end
end
