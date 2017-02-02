# frozen_string_literal: true
class CovertNextStageIdsToInteger < ActiveRecord::Migration[5.0]
  class Stage < ActiveRecord::Base
    serialize :next_stage_ids, Array
  end

  def up
    each_stage :to_i
  end

  def down
    each_stage :to_s
  end

  private

  def each_stage(operation)
    Stage.all.each do |stage|
      next if stage.next_stage_ids.empty?
      stage.next_stage_ids.map!(&operation)
      stage.save || puts("Manually clean up stage #{stage.id}")
    end
  end
end
