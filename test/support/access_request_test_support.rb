module AccessRequestTestSupport
  def enable_access_request(address_list = 'jira@example.com watchers@example.com', email_prefix = 'SAMSON ACCESS')
    @original_feature_flag = ENV['REQUEST_ACCESS_FEATURE']
    @original_address_list = ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST']
    @original_email_prefix = ENV['REQUEST_ACCESS_EMAIL_PREFIX']
    ENV['REQUEST_ACCESS_FEATURE'] = '1'
    ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'] = address_list
    ENV['REQUEST_ACCESS_EMAIL_PREFIX'] = email_prefix
  end

  def restore_access_request_settings
    ENV['REQUEST_ACCESS_FEATURE'] = @original_feature_flag
    ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'] = @original_address_list
    ENV['REQUEST_ACCESS_EMAIL_PREFIX'] = @original_email_prefix
  end
end
