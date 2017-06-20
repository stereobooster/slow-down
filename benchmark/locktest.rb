# https://gist.github.com/mperham/e0248bfb727ebf02ffd6b09172a85301

require 'benchmark'
require 'sidekiq-ent'
require 'redis-lock'
require 'redis-semaphore'
require 'ruby_redis_lock'

# monkey patch to remove exponential backoff in pmckee11-redis-lock,
# otherwise this benchmark does not complete successfully.
class Redis
  class Lock

    def attempt_lock(acquire_timeout)
      locked = false
      sleep_time = @base_sleep_in_secs
      when_to_timeout = Time.now + acquire_timeout
      until locked
        locked = @redis.set(@key, @instance_name, :nx => true, :ex => @auto_release_time)
        unless locked
          return false if Time.now > when_to_timeout
          sleep(sleep_time)
          sleep_time = [sleep_time, when_to_timeout - Time.now].min
        end
      end
      @time_locked = Time.now
      return true
    end

  end
end

# This is the connection pool that the 25 threads will share,
# each has their own connection to ensure no contention here.
Sidekiq.configure_client do |config|
  config.redis = { size: 25 }
end

# Create a concurrent limiter.  With size 1, the limiter effectively becomes a
# Mutex, only one caller is allowed to hold the lock at a time.
LIMIT = Sidekiq::Limiter.concurrent(:tester, 1, wait_timeout: 10, lock_timeout: 5)

$counter = 0

GEMS = {
  'redis-semaphore' => Proc.new do
    Sidekiq.redis do |conn|
      s = Redis::Semaphore.new(:tester, redis: conn)
      s.lock do
        sleep 0.1
        $counter += 1
      end
    end
  end,
  'pmckee11-redis-lock' => Proc.new do
    Sidekiq.redis do |conn|
      my_lock = Redis::Lock.new(conn, "my-lock-key", :auto_release_time => 30, :base_sleep => 100)
      my_lock.lock(120) do
        sleep 0.1
        $counter += 1
      end
    end
  end,
  'sidekiq-ent' => Proc.new do
    LIMIT.within_limit do
      sleep 0.1
      $counter += 1
    end
  end,
  'ruby_redis_lock' => Proc.new do
    Sidekiq.redis do |conn|
      conn.lock('tester', 60, 60) do
        sleep 0.1
        $counter += 1
      end
    end
  end
}

Benchmark.bm(20) do |x|
  GEMS.each_pair do |name, op|
    x.report(name) do
      jobs = Array.new(100) { op }
      threads = []
      25.times do
        threads << Thread.new do
          while operation = jobs.pop
            operation.call
          end
        end
      end
      threads.each(&:join)
      p [name, $counter]
      $counter = 0
    end
  end
end
