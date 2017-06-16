require "logger"
require "redis"

module LockDown
  class Configuration
    CONCURRENCY_MULTIPLIER = 1

    DEFAULTS = {
      lock_timeout: 60,
      redis: nil,
      redis_url: nil,
      redis_namespace: :lock_down,
      lock_namespace: :default,
      concurrency: 1,
      log_path: STDOUT,
      log_level: Logger::UNKNOWN,
      acquire_timeout: 0.5,
      retries: 2,
    }

    DEFAULTS.each do |key, default_value|
      define_method(key) do
        @options[key] || default_value
      end

      define_method("#{key}=") do |value|
        @options[key] = value
        invalidate
      end
    end

    def initialize(options)
      @options = DEFAULTS.merge(options)
    end

    def logger
      @logger ||= Logger.new(log_path).tap do |l|
        l.level = log_level
        l.formatter = proc do |severity, time, group_name, message|
          "#{time},#{severity},##{Process.pid},#{group_name}: #{message}\n"
        end
      end
    end

    def redis
      @redis ||= @options[:redis] || Redis.new(url: redis_url || ENV.fetch("REDIS_URL"))
    end

    def concurrency
      @concurrency ||= @options[:concurrency].ceil
    end

    def locks
      @locks ||= concurrency.times.map do |i|
        [redis_namespace, "#{lock_namespace}_#{i}"].compact.join(":")
      end
    end

    def seconds_per_retry(retry_count)
      return 0 if (retries == 0)
      acquire_timeout.to_f / retries
    end

    def invalidate
      @redis = nil
      @log_path = nil
      @log_level = nil
      @concurrency = nil
      @locks = nil
    end
  end
end
