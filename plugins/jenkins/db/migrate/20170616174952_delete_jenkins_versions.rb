# frozen_string_literal: true
class DeleteJenkinsVersions < ActiveRecord::Migration[5.1]
  class Version < ActiveRecord::Base
    self.table_name = 'versions'
  end

  def change
    Version.where(item_type: 'JenkinsJob').delete_all
  end
end
