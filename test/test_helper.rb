ENV["RAILS_ENV"] ||= "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'minitest/rails'
require 'webmock/minitest'

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def self.it_is_unauthorized
    it "sets a flash error" do
      request.flash[:error].wont_be_nil
    end

    it "redirects to the root url" do
      assert_redirected_to root_path
    end
  end

  class << self
    %w{admin deployer viewer}.each do |user|
      define_method "as_a_#{user}" do |&block|
        describe "as a #{user}" do
          setup { session[:user_id] = users(user).id }

          instance_eval(&block)
        end
      end
    end
  end
end
