# frozen_string_literal: true

# We saw initializers hanging boot so we are logging before every initializer is called to easily debug
# Test: boot up rails and look at the logs
if ENV['SERVER_MODE'] && !Rails.env.development?
  Rails::Engine.prepend(Module.new do
    def load(file, *)
      Rails.logger.info "Loading initializer #{file.sub("#{Bundler.root}/", "")}"
      super
    end
  end)
end
