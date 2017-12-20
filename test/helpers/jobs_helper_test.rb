# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe JobsHelper do
  include StatusHelper

  describe '#job_page_title' do
    it "renders" do
      @project = projects(:test)
      @job = jobs(:succeeded_test)
      job_page_title.must_equal "Foo deploy (succeeded)"
    end
  end
end
