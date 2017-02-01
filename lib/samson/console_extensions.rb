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

    # resets all caching in the controller and Rails.cache.fetch so we get worst-case performance
    # restart console to re-enable
    def use_clean_cache
      ActionController::Base.config.cache_store = Rails.cache = ActiveSupport::Cache::MemoryStore.new
    end
  end
end
