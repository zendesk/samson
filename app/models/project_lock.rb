class ProjectLock
  def self.grab(project, holder)
    if locks[project.id].try_lock
      locks[project.id].held_by = holder
      return true
    end
  end

  def self.release(project)
    locks[project.id].unlock
  end

  def self.owned?(project)
    locks[project.id].owned?
  end

  def self.owner(project)
    locks[project.id].held_by
  end

  private

  def self.locks
    Thread.main[:repo_locks] ||= ThreadSafe::Hash.new {|hash, key| hash[key] = MutexOwned.new }
  end
end
