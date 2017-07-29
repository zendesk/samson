# frozen_string_literal: true
# audit changes from the into an association without triggering a preload of their class
module AuditOnAssociation
  def audits_on_association(for_association, as_association, audit_name: as_association)
    method = :"record_change_in_#{for_association}_audit"

    around_save method
    around_destroy method

    define_method(method) do |&block|
      associated = Array(send(for_association))
      old = associated.map { |a| [a, yield(a)] }

      block.call # change happens

      old.each do |a, previous_state|
        a.send(as_association).reset
        current_state = yield(a)
        next if previous_state == current_state
        a.send(
          :write_audit,
          action: 'update',
          audited_changes: {audit_name.to_s => [previous_state, current_state]}
        )
      end
    end
  end
end
