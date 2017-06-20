require_relative "test_helper"
require_relative "support/tolerance"

class TestMultipleGroups < MiniTest::Test
  include Support::Tolerance

  def setup
    LockDown::Config.instance.connection_pool.with do |redis|
      redis.flushdb
      redis.flushall
    end
    @counter = Queue.new
    @threads = []
    sleep(0.05)
  end

  def teardown
    @threads.each(&:kill)
    LockDown::GroupStore.remove_all
  end

  def test_grouped_runs_with_concurency
    LockDown.group(:c) { |c| c.concurrency = 1 }
    LockDown.group(:d) { |c| c.concurrency = 4 }

    c_counter, d_counter = Queue.new, Queue.new
    c_error, d_error = Queue.new, Queue.new

    2.times do
      @threads << Thread.new do
        begin
          LockDown.run(:c, 0.5) { c_counter << 1; sleep 0.5 }
        rescue LockDown::Timeout
          c_error << 1
        end
      end
    end

    10.times do
      @threads << Thread.new do
        begin
          LockDown.run(:d) { d_counter << 1; sleep 0.5 }
        rescue LockDown::Timeout
          d_error << 1
        end
      end
    end

    Benchmark.realtime { @threads.each(&:join) }

    assert_equal(1, c_counter.size)
    assert_equal(1, c_error.size)
    assert_equal(4, d_counter.size)
    assert_equal(6, d_error.size)
  end
end
