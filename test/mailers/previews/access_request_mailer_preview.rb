# frozen_string_literal: true
# Preview all emails at http://localhost:3000/rails/mailers/access_request_mailer
require_relative '../../support/access_request_test_support'
class AccessRequestMailerPreview < ActionMailer::Preview
  include AccessRequestTestSupport
  def access_request_email
    enable_access_request do
      AccessRequestMailer.access_request_email(
        'localhost', User.first, 'manager@example.com', 'Dummy reason.',
        Project.all.pluck(:id), Role::DEPLOYER.id
      )
    end
  end
end
