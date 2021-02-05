# frozen_string_literal: true
class AuditsController < ApplicationController
  def index
    query = params[:search]&.to_unsafe_h&.select { |_, v| v.present? }
    key = query&.delete(:key)
    value = query&.delete(:value)
    scope = audit_scope.where(query)

    # find by changed key, by matching the yaml in audited_changes
    scope = scope.where(query_changes("%\n#{ActiveRecord::Base.send(:sanitize_sql_like, key)}:\n%")) if key

    # find by changed value ('from' or 'to'), by matching the yaml in audited_changes
    scope = scope.where(query_changes("%\n- #{ActiveRecord::Base.send(:sanitize_sql_like, value)}\n%")) if value

    @pagy, @audits = pagy(scope.order(id: :desc), page: params[:page], items: 25)
  end

  def show
    @audit = audit_scope.find(params.require(:id))
  end

  private

  # redoing what Audited::Audit.arel_table[:audited_changes].matches does without converting the value into yaml
  def query_changes(query)
    Arel::Nodes::Matches.new Audited::Audit.arel_table[:audited_changes], Arel::Nodes.build_quoted(query), nil, false
  end

  def audit_scope
    scope = Audited::Audit
    scope = scope.where.not(auditable_type: "User") if ENV["HIDE_USER_AUDITS"] # for privacy in public demo
    scope
  end
end
