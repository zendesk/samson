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
      params[:redirect_to] = "/bar?x=1"
      omniauth_path(:google).must_equal "/auth/google?origin=%2Fbar%3Fx%3D1"
    end

    it "blows up on hacking attempts" do
      params[:redirect_to] = "https://hackers.com/bar?x=1"
      assert_raises(ArgumentError) { omniauth_path(:google) }
    end
  end
end
