class MutexOwned < Mutex
  attr_accessor :held_by
end
