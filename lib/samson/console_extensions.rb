module Samson
  module ConsoleExtensions
    class Broadcaster
      attr_reader :subscribers

      def initialize(subscribers)
        @subscribers = subscribers
      end

      def respond_to?(*args)
        super || @subscribers.all? { |s| s.respond_to?(*args) }
      end

      def method_missing(method, *args, &block)
        @subscribers.map { |s| s.send(method, *args, &block) }.last
      end
    end

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
        "logged in as #{user.name}"
      end
    end

    # shows logs to stdout, but does still log them to the normal logfile for auditing
    # used during `rails c` to see what is going on under the hood
    def logs
      if Rails.logger.is_a?(Broadcaster)
        Rails.logger = Rails.logger.subscribers.first
      else
        Rails.logger = Broadcaster.new([Rails.logger, Logger.new(STDOUT)])
      end
    end
  end
end
