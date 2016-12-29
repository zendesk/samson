# frozen_string_literal: true
class Admin::SettingsController < ApplicationController
  before_action :authorize_super_admin!, except: [:index, :show]
  before_action :find_setting, only: [:update, :show, :destroy, :sync]

  def index
    @settings = Setting.all
  end

  def new
    @setting = Setting.new
    render :show
  end

  def show
  end

  def create
    @setting = Setting.new(setting_params)
    if @setting.save
      redirect_to({action: :index}, notice: "Created")
    else
      render :show
    end
  end

  def update
    if @setting.update_attributes(setting_params)
      redirect_to({action: :index}, notice: "Updated")
    else
      render :show
    end
  end

  def destroy
    @setting.destroy!
    redirect_to({action: :index}, notice: "Deleted #{@setting.name}")
  end

  private

  def setting_params
    params.require(:setting).permit(:name, :value)
  end

  def find_setting
    @setting = Setting.find(params.require(:id))
  end
end
