# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::BaseController do
  describe "#paginate" do
    it 'paginates array' do
      @controller.paginate(Array.new(1000).fill('a')).size.must_equal 1000
    end

    it 'paginates scope' do
      Deploy.stubs(:page).with(1).returns('foo')
      @controller.paginate(Deploy).must_equal 'foo'
    end
  end
end
