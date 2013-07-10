require 'sinatra'

class Pusher < Sinatra::Base
  enable :sessions, :logging
  set :root, Bundler.root

  get "/" do
    200
  end
end
