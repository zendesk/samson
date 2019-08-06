# frozen_string_literal: true
module AccessRequestHelper
  def display_access_request_link?
    AccessRequestsController.feature_enabled? && current_user && !current_user.super_admin?
  end

  def access_request_alternative_instruction
    ENV['ACCESS_REQUEST_ALTERNATIVE_INSTRUCTION']
  end

  def link_to_request_access
    if current_user.access_request_pending?
      'Access request pending.'
    else
      link_to 'Request additional access rights', new_access_request_path
    end
  end
end
