module Samson
  class Integration

    @@integrations = Rails.root.join('app','controllers', 'integrations').children(false).map do |controller_path|
      controller_path.to_s[/\A(?!base)(\w+)_controller.rb\z/, 1]
    end.compact

    def self.method_missing(*args)
      @@integrations.send(args)
    end

    def respond_to?(*args)
      super(args) || @@integrations.respond_to?(args)
    end
  end
end
