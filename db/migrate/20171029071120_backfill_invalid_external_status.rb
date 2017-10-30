# frozen_string_literal: true
class BackfillInvalidExternalStatus < ActiveRecord::Migration[5.1]
  class Build < ActiveRecord::Base
  end

  def up
    external = Build.where.not(external_id: nil)
    external.where.not(docker_repo_digest: nil).update_all(external_status: 'succeeded')
    external.where(docker_repo_digest: nil).update_all(external_status: 'errored')
  end

  def down
  end
end
