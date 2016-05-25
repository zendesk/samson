# memoize this due to a bug in MRI that shows up in multi-threaded code
# see https://github.com/puma/puma/issues/647
# can be removed on ruby 2.3.1+
if RUBY_VERSION > "2.3.0"
  warn "You can delete #{__FILE__} now"
else
  module AppRoutes
    def self.url_helpers
      @routes_url_helpers ||= Rails.application.routes.url_helpers
    end
  end
end
