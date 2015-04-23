module Samson
  class Integration

    @@sources = Rails.root.join('app','controllers', 'integrations').children(false).map do |controller_path|
      controller_path.to_s[/\A(?!base)(\w+)_controller.rb\z/, 1]
    end.compact

    cattr_reader :sources
  end
end
