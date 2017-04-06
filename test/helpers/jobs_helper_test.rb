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

  describe '#job_status_badge' do
    it 'renders' do
      job_status_badge(jobs(:succeeded_test)).must_include "Succeeded"
    end
  end
end
