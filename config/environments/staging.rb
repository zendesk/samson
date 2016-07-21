load File.expand_path '../production.rb', __FILE__

Samson::Application.configure do
  # show errors for easier debugging
  config.consider_all_requests_local = true
end
