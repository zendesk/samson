# Assumes the following methods are defined:
#   - id
#   - commit
#   - previous
#   - project
module HasChangeset
  extend ActiveSupport::Concern

  def changeset
    @changeset ||= changeset_to(previous)
  end

  def changeset_to(other)
    Changeset.find(project.github_repo, other.try(:commit), commit)
  end

  def hotfix?
    cached_val = Rails.cache.fetch([self.class, id, 'hotfix'].join('-'), expires_in: 1.year) do
      changeset.hotfix? ? 1 : 0
    end

    cached_val == 1
  end
end
