require_relative '../test_helper'

SingleCov.covered!

describe Project do
  let(:project) { projects(:test) }

  describe "#name_for_label" do
    it "cleanes up the name" do
      project.name = 'Ab(*c&d-1'
      project.name_for_label.must_equal 'ab-c-d-1'
    end
  end
end



