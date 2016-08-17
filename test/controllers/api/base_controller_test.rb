# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::BaseController do
  describe 'paginate array' do
    subject { n = []; 2000.times { n << ['a'] }; n }

    it 'paginates' do
      @controller.paginate(subject).size.must_equal 1000
    end
  end

  describe 'paginate scope' do
    subject { Deploy }
    let(:junk) { n = []; 2000.times { n << ['a'] }; n }

    it 'calls #page' do
      Deploy.stubs(:page).with(1).returns('foo')
      @controller.paginate(subject).must_equal 'foo'
    end
  end

  describe 'Doorkeeper Auth Status' do
    subject { Api::BaseController }
    it 'is allowed' do
      subject.api_accessible.must_equal true
    end
  end
end
