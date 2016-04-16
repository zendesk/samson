require_relative '../test_helper'

SingleCov.covered! uncovered: 37

describe DeploysHelper do
  describe '#syntax_highlight' do
    it "renders code" do
      syntax_highlight("puts 1").must_equal "puts <span class=\"integer\">1</span>"
    end
  end
end
