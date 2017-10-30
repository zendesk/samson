# frozen_string_literal: true
class AccessTokensController < ApplicationController
  before_action :token_scope

  def index
    @access_tokens = token_scope
  end

  def new
    @access_token = token_scope.new(
      scopes: 'default',
      application: ensure_personal_access_app
    )
  end

  def create
    token = token_scope.create!(
      params.
        require(:doorkeeper_access_token).
        permit(:description, :scopes, :application_id)
    )
    redirect_to(
      return_to_path,
      notice: "Token created: copy this token, it will not be shown again: <b>#{token.token}</b>".html_safe
    )
  end

  def destroy
    token_scope.find(params.require(:id)).destroy!
    redirect_to(
      return_to_path,
      notice: "Token deleted"
    )
  end

  private

  def return_to_path
    owner == current_user ? {action: :index} : owner
  end

  def ensure_personal_access_app
    Doorkeeper::Application.where(name: 'Personal Access Token').first_or_create!(
      scopes: '', # by default nothing is allowed ... scopes will come from access tokens
      redirect_uri: 'https://example.com' # this app will never redirect
    )
  end

  def owner
    @owner ||= begin
      if id = params[:doorkeeper_access_token]&.delete(:resource_owner_id).presence
        if can? :write, 'access_tokens'
          User.find(id)
        else
          unauthorized!
        end
      else
        current_user
      end
    end
  end

  def token_scope
    owner.access_tokens
  end
end
