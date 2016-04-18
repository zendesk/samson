require_relative '../test_helper'

SingleCov.covered!

describe JobsHelper do
  describe '#job_page_title' do
    it "renders" do
      @project = projects(:test)
      @job = jobs(:succeeded_test)
      job_page_title.must_equal "Project deploy (succeeded)"
    end
  end
end
