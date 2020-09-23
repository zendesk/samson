# frozen_string_literal: true
class AuditsController < ApplicationController
  def index
    query = params[:search]&.to_unsafe_h&.select { |_, v| v.present? }
    @pagy, @audits = pagy(audit_scope.where(query).order(id: :desc), page: params[:page], items: 25)
  end

  def show
    @audit = audit_scope.find(params.require(:id))
  end

  private

  def audit_scope
    scope = Audited::Audit
    scope = scope.where.not(auditable_type: "User") if ENV["HIDE_USER_AUDITS"] # for privacy in public demo
    scope
  end
end
