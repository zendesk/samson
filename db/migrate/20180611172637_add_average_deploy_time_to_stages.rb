# frozen_string_literal: true

class AddAverageDeployTimeToStages < ActiveRecord::Migration[5.2]
  class Deploy < ActiveRecord::Base; end

  def up
    add_column :stages, :average_deploy_time, :float

    # Grab data
    deploy_data = Deploy.pluck(:stage_id, :updated_at, :started_at, :created_at)

    stage_groups = deploy_data.group_by(&:first)

    stage_insert_values = stage_groups.map do |stage_id, deploys|
      average = deploys.reduce(0) do |sum, (_stage_id, updated_at, started_at, created_at)|
        sum + (updated_at - (started_at || created_at))
      end / deploys.size

      "(#{stage_id},#{average})"
    end

    if stage_insert_values.any?
      ActiveRecord::Base.transaction do
        # Create temporary table
        execute(<<~SQL)
          CREATE TEMPORARY TABLE averages (
            id int,
            average float
          );
        SQL

        execute(<<~SQL)
          INSERT INTO averages (id, average)
          VALUES #{stage_insert_values.join(',')};
        SQL

        # Backfill averages (sqlite doesn't support join in update)
        execute(<<~SQL)
          UPDATE stages
          SET average_deploy_time =
            (SELECT average
             FROM averages
             WHERE id = stages.id)
        SQL

        # Remove temporary table (sqlite doesn't support DROP TEMPORARY TABLE)
        execute(<<~SQL)
          DROP TABLE averages;
        SQL
      end
    end
  end

  def down
    remove_column :stages, :average_deploy_time
  end
end
