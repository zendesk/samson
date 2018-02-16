# frozen_string_literal: true
require 'csv'

class HomeController < ApplicationController
  include CurrentProject

  def index
    @deploys = deploys_scope.last(10)

    respond_to do |format|
      format.json do
        render_as_json :deploys, @deploys, allowed_includes: [:job, :project, :user, :stage]
      end
      format.csv do
        datetime = Time.now.strftime "%Y%m%d_%H%M"
        send_data as_csv, type: :csv, filename: "Deploys_search_#{datetime}.csv"
      end
      format.html
    end
  end

  def deploys_scope
    current_project&.deploys || Deploy
  end
end
