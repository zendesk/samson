# frozen_string_literal: true
module Searchable
  extend ActiveSupport::Concern

  module ClassMethods
    def search_by_criteria(criteria)
      scope = self
      scope = scope.search(criteria[:search]) if criteria[:search]
      scope.order(sort_column(criteria[:sort]) => sort_direction(criteria[:direction]))
    end

    private

    def sort_column(column)
      column_names.include?(column) ? column : 'created_at'
    end

    def sort_direction(direction)
      ['asc', 'desc'].include?(direction) ? direction : 'asc'
    end
  end
end
