# frozen_string_literal: true

class AddPipelinedToDeploys < ActiveRecord::Migration[5.1]
  def change
    add_reference :deploys, :triggering_deploy, foreign_key: {to_table: :deploys}, type: :integer
  end
end
