# Preview all emails at http://localhost:3000/rails/mailers/access_request_mailer
class AccessRequestMailerPreview < ActionMailer::Preview
  def access_request_email
    before
    email = AccessRequestMailer.access_request_email(
        'localhost', User.first, 'manager@example.com', 'Dummy reason.', Project.all.map(&:id))
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
