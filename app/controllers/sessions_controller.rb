class SessionsController < ApplicationController
  skip_before_filter :login_users

  def new
    if logged_in?
      redirect_to root_path
    else
      redirect_to '/auth/zendesk'
    end
  end

  def zendesk
    if auth_hash.info.role == "end-user" || auth_hash.info.email.blank?
      flash[:error] = 'You are unauthorized.'
    else
      role_id = if auth_hash.info.role == 'admin'
        Role::ADMIN.id
      else
        Role::VIEWER.id
      end

      user = User.find_or_create_from_hash(
        name: auth_hash.info.name,
        email: auth_hash.info.email,
        role_id: role_id
      )

      if user
        self.current_user = user
        flash[:notice] = "You have been logged in."
      else
        flash[:error] = "Could not log you in."
      end
    end

    redirect_to root_path
  end

  def failure
    flash[:error] = "Could not log you in."
    redirect_to root_path
  end

  def destroy
    logout!
    flash[:notice] = "You have been logged out."

    redirect_to root_path
  end

  protected

  def auth_hash
    request.env['omniauth.auth']
  end

  def strategy
    request.env['omniauth.strategy']
  end
end
