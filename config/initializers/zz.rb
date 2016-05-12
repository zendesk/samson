if Rails.env.development? && !ENV['SERVER_MODE']
  # make sure we do not regress into slow startup time by preloading too much
  Rails.configuration.after_initialize do
    [
      ActiveRecord::Base.send(:descendants).map(&:name),
      ActionController::Base.descendants,
      # (File.basename($0) != "rake" ? (defined?(Rake) && "rake") : nil), # https://github.com/rails/rails/issues/25029
      (defined?(Mocha) && "mocha")
    ].compact.flatten.each { |c| raise "#{c} should not be loaded" }
  end
end
