# frozen_string_literal: true
class AddRequestsToKubenretes < ActiveRecord::Migration[5.1]
  class KubernetesDeployGroupRole < ActiveRecord::Base
  end

  class KubernetesReleaseDoc < ActiveRecord::Base
  end

  def up
    [KubernetesReleaseDoc, KubernetesDeployGroupRole].each do |klass|
      add_column klass.table_name, :requests_cpu, :decimal, precision: 4, scale: 2
      add_column klass.table_name, :requests_memory, :integer
      klass.update_all("requests_memory = ram")
      klass.update_all("requests_cpu = cpu")
      change_column_null klass.table_name, :requests_cpu, false
      change_column_null klass.table_name, :requests_memory, false
      rename_column klass.table_name, :cpu, :limits_cpu
      rename_column klass.table_name, :ram, :limits_memory
    end
  end

  def down
    [KubernetesReleaseDoc, KubernetesDeployGroupRole].each do |klass|
      rename_column klass.table_name, :limits_cpu, :cpu
      rename_column klass.table_name, :limits_memory, :ram
      remove_column klass.table_name, :requests_cpu
      remove_column klass.table_name, :requests_memory
    end
  end
end
