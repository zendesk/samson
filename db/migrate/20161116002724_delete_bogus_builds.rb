# frozen_string_literal: true
class DeleteBogusBuilds < ActiveRecord::Migration[5.0]
  class Build < ActiveRecord::Base
    has_many :releases
  end

  class Release < ActiveRecord::Base
  end

  def change
    never_built = Build.where(docker_build_job_id: nil)
    never_built.joins(:releases).where('git_sha = commit').delete_all

    # update manually created releases so we do not lose information
    never_built.each do |build|
      build.releases.update_all(commit: build.git_sha)
    end
  end
end
