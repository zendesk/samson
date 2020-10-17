# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Inlinable do
  foo = Class.new(ActiveRecord::Base) do
    extend Inlinable

    allow_inline def bar1
      "bar1"
    end

    allow_inline def bar2
      "bar2"
    end
  end

  it "allows inline" do
    foo.allowed_inlines.count.must_equal 2
  end
end
