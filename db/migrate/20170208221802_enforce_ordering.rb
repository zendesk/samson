# frozen_string_literal: true
class EnforceOrdering < ActiveRecord::Migration[5.0]
  class Stage < ActiveRecord::Base
  end

  def up
    Stage.where(order: nil).update_all(order: 0)
    change_column_null :stages, :order, false
  end

  def down
    change_column_null :stages, :order, true
  end
end
