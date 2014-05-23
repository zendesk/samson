if Rails.env.development?
  Dotenv.overload(Bundler.root.join('.env'))
end
