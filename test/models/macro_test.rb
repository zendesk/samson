# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Macro do
  subject { macros(:test) }
end
