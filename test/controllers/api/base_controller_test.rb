# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::BaseController do
  describe 'Doorkeeper Auth Status' do
    subject { Api::BaseController }
    it 'is allowed' do
      subject.api_accessible.must_equal true
    end
  end
end
