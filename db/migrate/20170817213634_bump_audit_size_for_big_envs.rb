# frozen_string_literal: true
class BumpAuditSizeForBigEnvs < ActiveRecord::Migration[5.1]
  def up
    change_column :audits, :audited_changes, :text, limit: (1.gigabyte / 4) - 1
  end

  def down
    change_column :audits, :audited_changes, :text
  end
end
