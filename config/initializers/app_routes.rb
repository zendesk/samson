module AppRoutes
  # memoize this due to a bug in MRI that shows up in multi-threaded code
  # see https://github.com/puma/puma/issues/647, search for "bug in MRI"
  def self.url_helpers
    @@routes_url_helpers ||= Rails.application.routes.url_helpers
  end
end
