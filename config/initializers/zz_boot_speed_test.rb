# frozen_string_literal: true
if Rails.env.development? && !ENV['SERVER_MODE']
  # make sure we do not regress into slow startup time by preloading too much
  Rails.configuration.after_initialize do
    [
      ActiveRecord::Base.send(:descendants).map(&:name),
      ActionController::Base.descendants,
      (defined?(Mocha) && "mocha")
    ].compact.flatten.each { |c| raise "#{c} should not be loaded" }
  end
end
