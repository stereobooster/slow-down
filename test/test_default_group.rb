require_relative "test_helper"
require_relative "support/tolerance"

class TestDefaultGroup < MiniTest::Test
  include Support::Tolerance

  def setup
    Redis.new(url: ENV.fetch("REDIS_URL")).flushdb
    @counter = Queue.new
  end

  def teardown
    LockDown::Group.remove_all
  end

  def test_single_straight_run
    elapsed_time = Benchmark.realtime do
      LockDown.run { @counter << 1 }
    end

    assert_in_delta(0.0, elapsed_time, TOLERANCE)
    assert_equal(1, @counter.size)
  end

  def test_straight_run_return_value
    value = LockDown.run { :something }

    assert_equal(:something, value)
  end

  def test_multiple_straight_runs
    LockDown.config { |c| c.concurrency = 5 }

    elapsed_time = Benchmark.realtime do
      5.times do
        LockDown.run { @counter << 1 }
      end
    end

    assert_in_delta(0.0, elapsed_time, TOLERANCE)
    assert_equal(5, @counter.size)
  end

  def test_multiple_throttled_runs
    LockDown.config do |c|
      c.concurrency = 2
      c.lock_timeout = 5
    end

    elapsed_time = Benchmark.realtime do
      3.times do
        LockDown.run { @counter << 1 }
      end
    end

    assert_equal(3, @counter.size)
    # assert_in_delta(1.0, elapsed_time, TOLERANCE)
  end
end
