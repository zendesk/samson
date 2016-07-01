require_relative '../test_helper'

SingleCov.covered! uncovered: 33

describe DeploysHelper do
  describe '#syntax_highlight' do
    it "renders code" do
      syntax_highlight("puts 1").must_equal "puts <span class=\"integer\">1</span>"
    end
  end

  describe "#file_status_label" do
    it "shows added" do
      file_status_label('added').must_equal "<span class=\"label label-success\">A</span>"
    end

    it "shows removed" do
      file_status_label('removed').must_equal "<span class=\"label label-danger\">R</span>"
    end

    it "shows modified" do
      file_status_label('modified').must_equal "<span class=\"label label-info\">M</span>"
    end

    it "shows changed" do
      file_status_label('changed').must_equal "<span class=\"label label-info\">C</span>"
    end

    it "shows renamed" do
      file_status_label('renamed').must_equal "<span class=\"label label-info\">R</span>"
    end

    it "fails on unknown" do
      assert_raises(KeyError) { file_status_label('wut') }
    end
  end
end
