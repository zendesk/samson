# Preview all emails at http://localhost:3000/rails/mailers/request_access_mailer
class AccessRequestMailerPreview < ActionMailer::Preview
  def access_request_email
    before
    user = User.new(name: 'Dummy User', email: 'dummy@example.com', )
    email = AccessRequestMailer.access_request_email('localhost', user, 'manager@example.com', 'Dummy reason.')
    after
    email
  end

  private

  def before
    @original_address_list = ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST']
    @original_prefix = ENV['REQUEST_ACCESS_EMAIL_PREFIX']
    ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'] = 'jira@example.com watchers@example.com'
    ENV['REQUEST_ACCESS_EMAIL_PREFIX'] = 'SAMSON ACCESS'
  end

  def after
    ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'] = @original_address_list
    ENV['REQUEST_ACCESS_EMAIL_PREFIX'] = @original_prefix
  end
end
