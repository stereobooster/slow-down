require_relative "test_helper"

class TestConfigurations < MiniTest::Test
  def teardown
    LockDown::Group.remove_all
  end

  def test_configure_same_group_twice
    LockDown.config { |c| c.lock_timeout = 999 }

    assert_raises(LockDown::ConfigError) do
      LockDown.run(lock_timeout: 100)
    end
  end

  def test_redis_from_env_variable
    skip "todo: minitest mocking..."

    Object.stub_const(:ENV, { "REDIS_URL" => "redis://hello" }) do
      mock = MiniTest::Mock.new
      mock.expect(:call, true, [{ url: "redis://hello" }])

      Redis.stub(:new, mock) do
        config = LockDown.config
        config.redis
      end

      mock.verify
    end
  end

  def test_redis_from_instance
    redis = Redis.new
    config = LockDown.config do |c|
      c.redis = redis
    end

    assert_equal(redis, config.redis)
  end

  def test_redis_from_url
    skip "todo: minitest mocking..."

    config = LockDown.config do |c|
      c.redis_url = "redis://hello"
    end
  end

  def test_concurrency_from_config
    LockDown.config { |c| c.concurrency = 999 }

    assert_equal(999, LockDown.config.concurrency)
  end

  def test_timeout_from_config
    LockDown.config { |c| c.lock_timeout = 999 }

    assert_equal(999, LockDown.config.lock_timeout)
  end

  def test_retries_from_config
    LockDown.config { |c| c.retries = 999 }

    assert_equal(999, LockDown.config.retries)
  end

  def test_retries_from_run
    LockDown.run(retries: 999) {}

    assert_equal(999, LockDown.config.retries)
  end

  def test_concurrency_from_config
    LockDown.config { |c| c.concurrency = 999 }

    assert_equal(999, LockDown.config.concurrency)
  end

  def test_concurrency_from_run
    LockDown.run(concurrency: 999) {}

    assert_equal(999, LockDown.config.concurrency)
  end

  def test_concurrency_from_default_if_concurrency_below_1
    LockDown.config { |c| c.concurrency = 0.5 }

    assert_equal(1, LockDown.config.concurrency)
  end

  def test_concurrency_from_default_if_concurrency_above_1
    LockDown.config { |c| c.concurrency = 999 }

    assert_equal(999, LockDown.config.concurrency)
  end

  def test_locks
    LockDown.config { |c| c.redis_namespace = :hello; c.lock_namespace = :world; c.concurrency = 3 }

    assert_equal(["hello:world_0", "hello:world_1", "hello:world_2"], LockDown.config.locks)
  end

  def test_locks_from_default_and_group_name
    LockDown.config(:hello) { |c| c.concurrency = 3 }

    assert_equal(["lock_down:hello_0", "lock_down:hello_1", "lock_down:hello_2"], LockDown.config(:hello).locks)
  end

  def test_log_level
    LockDown.config { |c| c.log_level = Logger::DEBUG }

    assert_equal(Logger::DEBUG, LockDown.config.logger.level)
  end

  def test_log_path
    file = Tempfile.new("test-logger.log")

    LockDown.config { |c| c.log_path = file }
    assert_equal(file, LockDown.config.logger.instance_variable_get(:@logdev).dev)

    file.close!
  end

  def test_silent_logger_by_default
    assert_silent do
      LockDown.config do |c|
        c.log_path = $stdout
        c.lock_timeout = 0.5
        c.concurrency = 2
      end

      3.times do
        LockDown.run { 1 } rescue LockDown::Timeout
      end
    end
  end

  def test_info_logger
    assert_output(/^(.*),INFO,(#\d+),default: Lock (.+) was acquired for (\d+)ms$/) do
      LockDown.config do |c|
        c.log_path = $stdout
        c.log_level = Logger::INFO
        c.concurrency = 2
        c.lock_timeout = 0.5
      end

      LockDown.run { 1 }
    end
  end

  def test_seconds_per_retry
    LockDown.config { |c| c.retries = 10; c.acquire_timeout = 5 }

    10.times.each do |i|
      assert_equal(0.5, LockDown.config.seconds_per_retry(i + 1))
    end

    assert_equal(0.5, LockDown.config.seconds_per_retry(11))
  end
end
