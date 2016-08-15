# frozen_string_literal: true
require_relative '../../test_helper'
require 'warden/action_dispatch_patch'

SingleCov.covered!

describe ActionDispatchPatch::RequestObject do
  let(:ad_request) { ActionDispatch::Request.new({}) }
  let(:rack_request) { Rack::Request.new({}) }

  describe 'with ActionDispatch' do
    subject { ActionDispatchPatch::RequestObject.new(original_request) }
    let(:original_request) { ad_request }

    it 'does not blow up' do
      subject.authorization
    end
  end

  describe 'with Rack' do
    subject { ActionDispatchPatch::RequestObject.new(original_request) }
    let(:original_request) { rack_request }

    it 'does not blow up' do
      subject.authorization
    end
  end

  describe 'something else' do
    subject { ActionDispatchPatch::RequestObject.new(original_request) }

    let(:original_request) do
      class Foo
      end

      Foo.new
    end

    it 'blows up' do
      proc { subject.authorization }.must_raise RuntimeError
    end
  end
end
