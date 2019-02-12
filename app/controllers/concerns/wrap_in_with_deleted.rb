# frozen_string_literal: true
module WrapInWithDeleted
  extend ActiveSupport::Concern

  included do
    around_action :wrap_in_with_deleted, if: proc {
      request.get? && (with_deleted? || search_with_deleted?)
    }
  end

  protected

  def wrap_in_with_deleted
    Project.with_deleted do
      Stage.with_deleted do
        Deploy.with_deleted do
          yield
        end
      end
    end
  end

  # For both deleted and non-deleted resources
  def with_deleted?
    params[:with_deleted] == "true"
  end

  def search_with_deleted?
    params.dig(:search, :deleted) == "true"
  end
end
