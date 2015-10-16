module Searchable
  extend ActiveSupport::Concern

  included do
    def self.search_by_criteria(criteria)
      scope = self
      scope = scope.search(criteria[:search]) if criteria[:search]
      scope.order("#{sort_column(criteria[:sort])} #{sort_direction(criteria[:direction])}").page(criteria[:page])
    end

    private

    def self.sort_column(column)
      column_names.include?(column) ? column : 'created_at'
    end

    def self.sort_direction(direction)
      %w[asc desc].include?(direction) ? direction : 'asc'
    end
  end
end
