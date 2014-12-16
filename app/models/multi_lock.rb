class MultiLock
  cattr_accessor(:mutex) { Mutex.new }
  cattr_accessor(:locks) { {} }

  class << self
    def lock(id, holder, options)
      locked = false
      end_time = Time.now + options.fetch(:timeout)
      until Time.now > end_time
        break if locked = try_lock(id, holder)

        continue = options.fetch(:failed_to_lock).call(locks[id])
        break unless continue

        sleep 1
      end
      yield if locked
      locked
    ensure
      unlock(id) if locked
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
