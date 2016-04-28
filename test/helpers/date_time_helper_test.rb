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
end
