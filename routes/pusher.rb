require 'sinatra'

class Pusher < Sinatra::Base
  enable :sessions, :logging

  get "/" do
    200
  end
end
