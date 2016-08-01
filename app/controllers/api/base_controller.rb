require 'doorkeeper_auth'

class Api::BaseController < ApplicationController
  api_accessible! true
end
