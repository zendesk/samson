# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SessionsHelper do
  describe "#omniauth_path" do
    let(:params) { {} }

    it "builds a path" do
      omniauth_path(:google).must_equal "/auth/google?origin=%2F"
    end

    it "escapes fancy paths" do
      params[:origin] = "http://foo.com/bar?x=1"
      omniauth_path(:google).must_equal "/auth/google?origin=http%3A%2F%2Ffoo.com%2Fbar%3Fx%3D1"
    end
  end
end
