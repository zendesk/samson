# frozen_string_literal: true
# https://github.com/seattlerb/minitest/issues/666
Object.prepend(Module.new do
  def must_equal(*args)
    if args.first.nil?
      must_be_nil(*args[1..])
    else
      super
    end
  end
end)
