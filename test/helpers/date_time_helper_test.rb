# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DateTimeHelper do
  describe '#datetime_to_js_ms' do
    it "returns milliseconds" do
      datetime_to_js_ms(5).must_equal 5000
      t = Time.now
      datetime_to_js_ms(t).must_equal t.to_i * 1000
    end
  end

  describe "#render_time" do
    let(:ts) { Time.parse("2016-04-18T17:46:10.337+00:00") }
    let(:current_user) { users(:admin) }

    it "formats time in the uesrs default preference" do
      render_time(ts, nil).must_equal(
        "<span data-time=\"1461001570000\" class=\"mouseover\">Mon, 18 Apr 2016 17:46:10 +0000</span>"
      )
    end

    it "formats time in utc" do
      render_time(ts, 'utc').must_equal(
        "<time datetime=\"2016-04-18 17:46:10 UTC\">2016-04-18 17:46:10 UTC</time>"
      )
    end

    it "formats time in utc if no timezone cookie is set" do
      render_time(ts, 'local').must_equal(
        "<time datetime=\"2016-04-18 17:46:10 UTC\">2016-04-18 17:46:10 UTC</time>"
      )
    end

    it "formats local time in America/Los_Angeles via cookie set by JS" do
      cookies[:timezone] = 'America/Los_Angeles'
      render_time(ts, 'local').must_equal(
        "<time datetime=\"2016-04-18 10:46:10 -0700\">2016-04-18 10:46:10 -0700</time>"
      )
    end

    it "formats local time in America/New_York via cookie set by JS" do
      cookies[:timezone] = 'America/New_York'
      render_time(ts, 'local').must_equal(
        "<time datetime=\"2016-04-18 13:46:10 -0400\">2016-04-18 13:46:10 -0400</time>"
      )
    end

    it "formats time relative" do
      render_time(ts, 'foobar').must_equal(
        "<span data-time=\"1461001570000\" class=\"mouseover\">Mon, 18 Apr 2016 17:46:10 +0000</span>"
      )
    end
  end
end
