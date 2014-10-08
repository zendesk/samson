class MultiLock
  cattr_accessor(:mutex) { Mutex.new }
  cattr_accessor(:locks) { {} }
  
  class << self
    def lock(id, holder, options)
      locked = false
      end_time = Time.now + options.fetch(:timeout)
      loop do
        locked = try_lock(id, holder)
        break if locked || Time.now > end_time
        options.fetch(:failed_to_lock).call
        sleep 1
      end
      yield if locked
      locked
    ensure
      unlock(id) if locked
    end

    def owner(id)
      locks[id]
    end

    private

    def try_lock(id, holder)
      mutex.synchronize do
        if locks[id]
          false
        else
          locks[id] = holder
          true
        end
      end
    end

    def unlock(id)
      mutex.synchronize do
        locks.delete(id)
      end
    end
  end
end
