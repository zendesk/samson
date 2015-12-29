module LocksHelper
  def delete_lock_options
    [
      ['Unlock in 1 hour', 1.hour],
      ['Unlock in 2 hours', 2.hours],
      ['Unlock in 4 hours', 4.hours],
      ['Unlock in 8 hours', 8.hours],
      ['Unlock in 1 day', 1.day],
      ['Never', nil]
    ]
  end
end
