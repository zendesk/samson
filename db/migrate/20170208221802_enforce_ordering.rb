# frozen_string_literal: true
class EnforceOrdering < ActiveRecord::Migration[5.0]
  def up
    change_column_default :stages, :order, 0
    change_column_null :stages, :order, false
    change_column_default :stages, :order, nil
  end

  def down
    change_column_null :stages, :order, true
    change_column_default :stages, :order, nil
  end
end
