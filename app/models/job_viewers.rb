class JobViewers < ThreadSafe::Array
  def initialize(output)
    @output = output
    super()
  end

  def push(*args)
    super.tap do
      @output.write(:viewers, self)
    end
  end

  def delete(*args)
    super.tap do
      @output.write(:viewers, self)
    end
  end
end
