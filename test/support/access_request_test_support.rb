# frozen_string_literal: true
module AccessRequestTestSupport
  def enable_access_request(
    address_list = 'jira@example.com watchers@example.com',
    email_prefix: 'SAMSON ACCESS',
    &block
  )
    with_env(
      REQUEST_ACCESS_FEATURE: '1',
      REQUEST_ACCESS_EMAIL_ADDRESS_LIST: address_list,
      REQUEST_ACCESS_EMAIL_PREFIX: email_prefix,
      &block
    )
  end
end
