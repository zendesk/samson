# frozen_string_literal: true
class AuditsController < ApplicationController
  def index
    query = params[:search]&.to_unsafe_h&.select { |_, v| v.present? }
    @audits = Audited::Audit.where(query).order(id: :desc).page(page).per(25)
  end

  def show
    @audit = Audited::Audit.find(params.require(:id))
  end
end
