# frozen_string_literal: true
class JobViewers
  def initialize(output)
    @list = Concurrent::Array.new
    @output = output
  end

  def push(*args)
    @list.push *args
    output
  end

  def delete(*args)
    @list.delete *args
    output
  end

  def to_a
    @list.dup
  end

  private

  def output
    @output.write(self, :viewers)
  end
end
