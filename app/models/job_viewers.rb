class JobViewers < ThreadSafe::Array
  def initialize(output)
    @output = output
    super()
  end

  def push(*args)
    super.tap { output }
  end

  def delete(*args)
    super.tap { output }
  end

  private

  def output
    @output.write(self, :viewers)
  end
end
