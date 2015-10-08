module AccessRequestHelper
  def display_access_request_link?(flash_type = :authorization_error)
    flash_type == :authorization_error &&
        ENV['REQUEST_ACCESS_FEATURE'].present? &&
        !current_user.is_super_admin?
  end

  def link_to_request_access
    current_user.access_request_pending ?
        'Access request pending.' :
        (link_to 'Request additional access rights', new_access_request_path)
  end
end
