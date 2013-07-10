require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/namespace'

require Bundler.root.join("config", "data_mapper.rb")

class Pusher < Sinatra::Base
  enable :sessions, :logging
  set :root, Bundler.root
  set :protection, except: :session_hijacking

  register Sinatra::Namespace

  configure :development do
    register Sinatra::Reloader
  end

  get "/" do
    erb :index
  end
end

require_relative "tasks"
require_relative "tail"
