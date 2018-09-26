# frozen_string_literal: true
class MultiLock
  cattr_accessor(:mutex) { Mutex.new }
  cattr_accessor(:locks) { {} }

  class << self
    extend ::Samson::PerformanceTracer::Tracers

    def lock(id, holder, options)
      locked = wait_for_lock(id, holder, options)
      yield if locked
      locked
    ensure
      unlock(id) if locked
    end

    private

    def wait_for_lock(id, holder, options)
      end_time = Time.now + options.fetch(:timeout)
      until Time.now > end_time
        return true if try_lock(id, holder)
        options.fetch(:failed_to_lock).call(locks[id])
        sleep 1
      end
      false
    end
    add_tracer :wait_for_lock

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
