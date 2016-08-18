class UserPresenter
  def initialize(user, options = {})
    @user = user
    @options = options
  end

  def present
    return unless @user

    {
      id: @user.id,
      name: @user.name,
      email: @user.email,
      role: @user.role_id,
      external_id: @user.external_id,
      desktop_notify: @user.desktop_notify,
      integration: @user.integration,
      access_request_pending: @user.access_request_pending,
      time_format: @user.time_format,
      created_at: @user.created_at,
      updated_at: @user.updated_at,
      deleted_at: @user.deleted_at,
    }.as_json
  end
end
