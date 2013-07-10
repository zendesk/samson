require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/namespace'

class Pusher < Sinatra::Base
  enable :sessions, :logging
  set :root, Bundler.root

  register Sinatra::Namespace

  configure :development do
    register Sinatra::Reloader
  end

  get "/" do
    erb :index
  end
end

require_relative "tasks"
