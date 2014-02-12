class ProjectLock
  def self.grab(project)
    locks[project.id].try_lock
  end

  def self.release(project)
    locks[project.id].unlock
  end

  def self.owned?(project)
    locks[project.id].owned?
  end

  def self.init(project)
    locks[project.id]
  end

  private

  def self.locks
    Thread.main[:repo_locks] ||= ThreadSafe::Hash.new {|hash, key| hash[key] = Mutex.new }
  end
end
