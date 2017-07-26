# frozen_string_literal: true
module AcceptsEnvironmentVariables
  ASSIGNABLE_ATTRIBUTES = {environment_variables_attributes: [:name, :value, :scope_type_and_id, :_destroy, :id]}.freeze

  def self.included(base)
    base.class_eval do
      has_many :environment_variables, as: :parent, dependent: :destroy, inverse_of: :parent
      accepts_nested_attributes_for :environment_variables, allow_destroy: true, reject_if: ->(a) { a[:name].blank? }
      validate :validate_unique_environment_variables

      private

      def validate_unique_environment_variables
        return if persisted? && !environment_variables.proxy_association.loaded?

        grouped = environment_variables.group_by { |e| [e.name, e.scope_type, e.scope_id, e.parent_type, e.parent_id] }
        return if grouped.size == environment_variables.size

        bad = grouped.select { |_, g| g.size > 1 }
        errors.add :base, "Non-Unique environment variables found for: #{bad.map(&:first).map(&:first).join(", ")}"
      end
    end
  end
end
