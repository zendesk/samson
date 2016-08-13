# frozen_string_literal: true
module Samson
  module ConsoleExtensions
    # used to fake a login while debugging in a `rails c` console session
    # so app.get 'http://xyz.com/protected/resource' works
    def login(user)
      CurrentUser.class_eval do
        define_method :current_user do
          user
        end

        # this would call warden and cause a redirect
        define_method :login_user do |&block|
          block.call
        end

        define_method :verify_authenticity_token do
        end
        "logged in as #{user.name}"
      end
    end
  end
end
