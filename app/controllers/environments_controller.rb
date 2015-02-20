class EnvironmentsController < ApplicationController
  before_action :authorize_admin!, except: [:show, :index]

  def index
  end

  def show
  end
end
