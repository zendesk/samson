# frozen_string_literal: true
module OutputBufferSupport
  def wait_for_listeners(buffer, size = 1)
    until buffer.listeners.size == size && buffer.listeners.all? { |l| l.num_waiting == 1 }
      sleep(0.1)
    end
  end
end
