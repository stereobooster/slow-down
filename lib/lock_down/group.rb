require "securerandom"

module LockDown
  class Group
    attr_reader :name

    def initialize(name, options = {})
      @name = name
      @options = DEFAULTS.merge(options)
    end

    DEFAULTS = {
      concurrency: nil,
      lock_timeout: 60,
      acquire_timeout: 0,
      retries: 0,
    }

    DEFAULTS.each do |key, default_value|
      define_method(key) do
        @options[key] || default_value
      end

      define_method("#{key}=") do |value|
        @options[key] = value
      end
    end

    def run(timeout = nil)
      expires_at, iteration = Time.now + acquire_timeout, 0
      lock_token = nil

      begin
        begin
          lock_token = lock(timeout)
        rescue Redis::TimeoutError
          # can not connect to Redis execute given code as is
          return yield
        end

        if lock_token
          # acquired lock, breaking the wait loop
          break
        else
          # sleep till next try
          wait(iteration += 1)
        end
      end until Time.now > expires_at

      # didn't manage to acquire lock for the given time
      raise Timeout unless lock_token

      begin
        res = yield
        unlock(lock_token)
        return res
      rescue Exception
        unlock(lock_token)
        raise
      end
    end

    def reset
      locks.each do |key|
        LockDown.connection_pool.with do |redis|
          redis.del(key)
        end
      end
    end

    private

    def locks
      @locks ||= concurrency.times.map do |i|
        [Config.instance.redis_namespace, "#{name}_#{i}"].compact.join(":")
      end
    end

    def lock(timeout)
      ttl = ((timeout || lock_timeout) * 1000).round
      lockid = SecureRandom.hex(20)
      LockDown.connection_pool.with do |redis|
        locks.each do |key|
          if redis.client.call([:set, key, lockid, :nx, :px, ttl])
            LockDown.logger.info(name) { "Lock #{key} was acquired for #{ttl}ms" }
            return { key: key, lockid: lockid }
          end
        end
      end

      return false
    end

    def unlock(lock_token)
      key = lock_token.fetch(:key)
      lockid = lock_token.fetch(:lockid)
      LockDown.connection_pool.with do |redis|
        # comparing lockid for case if lock was taken by another instance
        if redis.call([:get, key]) == lockid
          redis.call([:del, key])
        end
      end
    rescue Redis::TimeoutError
      # ignore this error, we made our best trying to unlock
    end

    def wait(iteration)
      LockDown.logger.debug(name) { "Sleeping for #{seconds_per_retry(iteration) * 1000}ms" }
      sleep(seconds_per_retry(iteration))
    end

    def seconds_per_retry(retry_count)
      return 0 if (retries == 0)
      acquire_timeout.to_f / retries
    end
  end
end
