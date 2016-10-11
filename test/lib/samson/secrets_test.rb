# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::Secrets do
  it "uses relative_model_naming" do
    assert Samson::Secrets.use_relative_model_naming?
  end
end
