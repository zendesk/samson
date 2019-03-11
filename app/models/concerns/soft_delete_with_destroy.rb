# frozen_string_literal: true

# soft_deletion gem doesn't destroy relations with dependent: :destroy, only soft_delete's them if they are
# soft_deletable. This leads to orphaned records of soft_deleted objects. This fills in the missing logic in the
# gem -- finding all child records which are not soft_deletable and have the `dependent: :destroy` callback and deleting
# them.
# Setting a new instance var, to avoid having saving an already deleted record delete it's associations
#
# Inside the transaction so it rolls back if anything fails
module SoftDeleteWithDestroy
  def self.included(base)
    base.attr_accessor :in_soft_delete
    base.around_soft_delete do |_, inner|
      @in_soft_delete = true
      inner.call
    ensure
      @in_soft_delete = false
    end

    base.before_update do
      if @in_soft_delete
        to_destroy = base.reflect_on_all_associations.select do |association|
          association.options[:dependent] == :destroy && !association.klass.method_defined?(:soft_delete!)
        end

        to_destroy.each { |association| Array(send(association.name)).each(&:destroy!) }
      end
    end
  end
end
