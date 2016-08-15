# frozen_string_literal: true
class NilifyServiceNames < ActiveRecord::Migration
  class KubernetesRole < ActiveRecord::Base
  end

  def up
    KubernetesRole.where(service_name: "").update_all(service_name: nil)
  end

  def down
  end
end
