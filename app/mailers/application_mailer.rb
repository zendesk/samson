class ApplicationMailer < ActionMailer::Base
  default from: "deploys@#{Rails.application.config.samson.email.sender_domain}"
end
