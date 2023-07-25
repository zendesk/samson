# frozen_string_literal: true

class AccessTokensController < ResourceController
  before_action :set_resource, except: [:index]

  private

  def owner
    @owner ||= begin
      id = params[:doorkeeper_access_token]&.delete(:resource_owner_id).presence || current_user.id
      token = current_user.access_tokens.new { |t| t.resource_owner_id = id }
      if can? :write, :access_tokens, token
        User.find(id)
      else
        unauthorized!
      end
    end
  end

  def redirect_to_from_params
    owner == current_user ? {action: :index} : owner
  end

  def redirect_after_save
    redirect_to(
      redirect_to_from_params,
      notice: <<~HTML.html_safe
        Token created: copy this token, it will not be shown again: <b>#{@resource.token}</b><br/>
        Use with 'Authorization: Bearer #{@resource.token}' header.
      HTML
    )
  end

  def ensure_personal_access_app
    Doorkeeper::Application.where(name: 'Personal Access Token').first_or_create!(
      scopes: '', # by default nothing is allowed ... scopes will come from access tokens
      redirect_uri: 'https://example.com' # this app will never redirect
    )
  end

  def resource_name
    'access_token'
  end

  def resource_class
    owner.access_tokens
  end

  def render_resource_as_json(**args)
    # Override constraints in Doorkeeper::AccessToken
    render_as_json resource_name, @resource.serializable_hash, nil, **args, allowed_includes: nil
  end

  def resource_params
    if action_name == 'new'
      ActionController::Parameters.new(
        scopes: 'default',
        application: ensure_personal_access_app
      ).permit!
    else
      params.
        require(:doorkeeper_access_token).
        permit(:description, :scopes, :application_id)
    end
  end
end
