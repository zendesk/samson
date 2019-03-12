# frozen_string_literal: true
class ChangelogsController < ApplicationController
  include CurrentProject

  def show
    if params[:start_date].blank? || params[:end_date].blank?
      params[:start_date] = (Date.today.beginning_of_week - 7.days).to_s
      params[:end_date] = Date.today.to_s
    end

    @branch = params[:branch] || 'master'
    @start_date = Date.strptime(params[:start_date], '%Y-%m-%d')
    @end_date = Date.strptime(params[:end_date], '%Y-%m-%d')
    @changeset = Changeset.new(
      current_project,
      "#{@branch}@{#{@start_date}}",
      "#{@branch}@{#{@end_date}}"
    )
  end
end
