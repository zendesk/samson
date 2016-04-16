require_relative '../test_helper'

SingleCov.covered! uncovered: 12

describe BuildsHelper do
  describe '#build_page_title' do
    it "renders" do
      @project = projects(:test)
      @build = builds(:staging)
      build_page_title.must_equal "Build #{@build.id} - Project"
    end
  end
end
