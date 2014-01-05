require 'dotenv'
Dotenv.load

port ENV['PORT'] || 8080
threads 8,250
preload_app!
