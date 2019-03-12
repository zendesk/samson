# frozen_string_literal: true

Stage.class_eval do
  include ScopesEnvironmentVariables

  accepts_nested_attributes_for :scoped_environment_variables, allow_destroy: true, reject_if: ->(a) { a[:name].blank? }
  validate :validate_unique_scoped_environment_variables

  def scoped_environment_variables_attributes=(attrs)
    attrs.values.each do |attr|
      attr['parent_id'] = project_id
      attr['parent_type'] = 'Project'
    end
    super(attrs)
  end

  private

  def validate_unique_scoped_environment_variables
    variables = scoped_environment_variables.map(&:name)
    dup_variables = variables.select { |e| variables.count(e) > 1 }
    return if dup_variables.empty?

    errors.add :base, "Non-Unique environment variables found for: #{dup_variables.uniq.join(", ")}"
  end
end
