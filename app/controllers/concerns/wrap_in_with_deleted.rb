# frozen_string_literal: true
module WrapInWithDeleted
  extend ActiveSupport::Concern

  included do
    around_action :wrap_in_with_deleted
  end

  protected

  def search_deleted
    params.dig(:search, :deleted)
  end

  def wrap_in_with_deleted(&block)
    # when searching for deleted, make sure results are shown
    if deleted = search_deleted
      params[:with_deleted] ||= deleted
    end

    if value = params[:with_deleted].presence
      raise "with_deleted is only supported for get requests" unless request.get?
      klasses = value.split(",").map(&:safe_constantize)
      klasses.inject(block) { |inner, klass| -> { klass.with_deleted(&inner) } }.call
    else
      yield
    end
  end
end
