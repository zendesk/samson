require_relative '../test_helper'

describe MultiLock do
  before do
    MultiLock.send(:unlock, 1)
    MultiLock.send(:unlock, 2)
  end

  describe ".lock" do
    let(:calls) { [] }

    def assert_time(operand, number)
      t = Time.now.to_f
      yield
      assert_operator Time.now.to_f + number, operand, t
    end

    it "locks" do
      MultiLock.lock(1, "a", timeout: 1, failed_to_lock: lambda{ calls << 2  }) { calls << 1 }.must_equal true
      assert_equal [1], calls
    end

    it "expires when unable to lock" do
      MultiLock.send(:try_lock, 1, "a")

      assert_time :>, 1 do
        MultiLock.lock(1, "a", timeout: 1, failed_to_lock: lambda{ calls << 2  }) { calls << 1 }.must_equal false
      end
      assert_equal [2], calls
    end
  end

  describe ".try_lock" do
    it "locks" do
      MultiLock.send(:try_lock, 1, "a").must_equal true
    end

    it "does not lock locked" do
      MultiLock.send(:try_lock, 1, "a").must_equal true
      MultiLock.send(:try_lock, 1, "a").must_equal false
    end

    it "scoped by key" do
      MultiLock.send(:try_lock, 1, "a").must_equal true
      MultiLock.send(:try_lock, 2, "a").must_equal true
    end
  end

  describe ".unlock" do
    it "can unlock unlocked" do
      MultiLock.send(:unlock, 1)
    end

    it "can unlock locked" do
      MultiLock.send(:try_lock, 1, "a")
      MultiLock.send(:unlock, 1)
      MultiLock.send(:try_lock, 1, "a")
    end
  end

  describe ".owner" do
    it "is nil for unknown" do
      MultiLock.owner(1).must_equal nil
    end

    it "is owner for known" do
      MultiLock.send(:try_lock, 1, "a")
      MultiLock.owner(1).must_equal "a"
    end
  end
end
