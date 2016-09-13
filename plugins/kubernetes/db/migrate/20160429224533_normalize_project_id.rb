# frozen_string_literal: true
class NormalizeProjectId < ActiveRecord::Migration[4.2]
  class KubernetesRelease < ActiveRecord::Base
    belongs_to :build
  end

  class Build < ActiveRecord::Base
  end

  def up
    add_column :kubernetes_releases, :project_id, :integer

    KubernetesRelease.find_each do |kr|
      kr.update_column :project_id, kr.build.project_id
    end

    change_column_null :kubernetes_releases, :project_id, false
  end

  def down
    remove_column :kubernetes_releases, :project_id
  end
end
