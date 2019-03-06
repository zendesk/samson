# frozen_string_literal: true

# soft_deletion gem doesn't destroy relations with dependent: :destroy, only safe_delete's them if they are
# safe_deletable. This leads to orphaned records of safe_deleted objects. This fills in the missing logic in the
# gem -- finding all child records which are not safe_deletable and have the dependent: :destroy callback and deleting
# them.
module SoftDeleteWithDestroy
  def self.included(base)
    base.before_soft_delete do
      mark_as_deleted # We need associations to skip validations during deletion of their parent
      to_destroy = base.reflect_on_all_associations.select do |association|
        association.options[:dependent] == :destroy && !association.klass.method_defined?(:soft_delete!)
      end

      to_destroy.each { |association| Array(send(association.name)).each(&:destroy!) }
    end
  end
end
