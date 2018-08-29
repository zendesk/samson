# frozen_string_literal: true
module Samson
  class Integration
    SOURCES = Rails.root.join('app', 'controllers', 'integrations').children(false).map do |controller_path|
      # keep in sync with app/controllers/integrations/base_controller.rb#service_name
      controller_path.to_s[/\A(?!base)(\w+)_controller.rb\z/, 1]
    end.compact.freeze
  end
end
