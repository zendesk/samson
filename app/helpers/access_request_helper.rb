module AccessRequestHelper
  def display_access_request_link?(flash_type)
    flash_type == :authorization_error && AccessRequestsController.feature_enabled?
  end

  def link_to_request_access
    current_user.access_request_pending ?
        'Access request pending.' :
        (link_to 'Request access.', new_access_request_path)
  end
end
