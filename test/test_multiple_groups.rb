require_relative "test_helper"
require_relative "support/tolerance"

class TestMultipleGroups < MiniTest::Test
  include Support::Tolerance

  # attr_reader :redis

  def setup
    @redis = Redis.new(url: ENV.fetch("REDIS_URL"))
    @redis.flushdb
    @redis.flushall
    @counter = Queue.new
    @threads = []
  end

  def teardown
    @threads.each(&:kill)
    LockDown::Group.remove_all
  end

  # def test_grouped_straight_runs
  #   LockDown.config(:a) { |c| c.concurrency = 5 }
  #   LockDown.config(:b) { |c| c.concurrency = 5 }

  #   elapsed_time = Benchmark.realtime do
  #     5.times do
  #       LockDown.run(:a) { @counter << 1 }
  #       LockDown.run(:b) { @counter << 1 }
  #     end
  #   end

  #   # assert_in_delta(0.0, elapsed_time, TOLERANCE)
  #   assert_equal(10, @counter.size)
  # end

  # def test_grouped_throttled_runs
  #   LockDown.config(:a) { |c| c.concurrency = 2; c.lock_timeout = 1.5 }
  #   LockDown.config(:b) { |c| c.concurrency = 5; c.lock_timeout = 1.5 }

  #   begin
  #     3.times do
  #       @threads << Thread.new do
  #         LockDown.run(:a) { @counter << 1 }
  #       end
  #     end

  #     9.times do
  #       @threads << Thread.new do
  #         LockDown.run(:b) { @counter << 1 }
  #       end
  #     end

  #     elapsed_time = Benchmark.realtime { @threads.each(&:join) }
  #   rescue LockDown::Timeout
  #   end

  #   assert_equal(12, @counter.size)
  # end

  def test_grouped_throttled_runs_with_timeout
    LockDown.config(:c) { |c| c.concurrency = 1 }
    LockDown.config(:d) { |c| c.concurrency = 4 }

    c_counter, d_counter = Queue.new, Queue.new

    2.times do
      @threads << Thread.new do
        LockDown.run(:c, 0.5) { c_counter << 1; sleep 0.5 }
      end
    end

    10.times do
      @threads << Thread.new do
        LockDown.run(:d) { d_counter << 1; sleep 1.2 }
      end
    end

    sleep(0.2)
    assert_equal(1, c_counter.size)
    assert_equal(4, d_counter.size)

    elapsed_time = Benchmark.realtime { @threads.each(&:join) }
  end
end
