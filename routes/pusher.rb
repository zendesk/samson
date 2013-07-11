require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/namespace'

require Bundler.root.join("config", "data_mapper.rb")

Dir.glob(Bundler.root.join("helpers", "*.rb")) do |file|
  require file
end

# Needed for process watching
EventMachine.epoll if EventMachine.epoll?
EventMachine.kqueue = true if EventMachine.kqueue?

class Pusher < Sinatra::Base
  enable :sessions, :logging
  set :root, Bundler.root
  set :protection, except: :session_hijacking

  configure :test do
    disable :show_exceptions
  end

  register Sinatra::Namespace

  configure :development do
    register Sinatra::Reloader
  end

  helpers FormsHelper

  get "/" do
    erb :index
  end
end

require_relative "tasks"
require_relative "jobs"
