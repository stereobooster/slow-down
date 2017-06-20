require "securerandom"
require "lock_down/configuration"
# require 'concurrent'

module LockDown
  class Group
    def self.all
      @groups || {}
    end

    def self.find(name)
      all[name]
    end

    def self.create(name, options = {})
      @groups ||= {}
      @groups[name] = Group.new(name, options)
    end

    def self.find_or_create(name, options = {})
      if all[name] && !options.empty?
        all[name].config.logger.error(name) { "Group #{name} has already been configured elsewhere" }
        fail ConfigError, "Group #{name} has already been configured elsewhere - you may not override configurations"
      end

      all[name] || create(name, options)
    end

    def self.remove(group_name)
      return unless group = Group.find(group_name)

      group.reset
      @groups.delete(group_name)
    end

    def self.remove_all
      all.each_value(&:remove)
    end

    attr_reader :name, :config

    def initialize(name, options = {})
      @name = name
      @config = Configuration.new({ lock_namespace: name }.merge(options))
    end

    def run(timeout = nil)
      expires_at, iteration = Time.now + config.acquire_timeout, 0
      config.logger.info(name) { "Run attempt initiatied, times out at #{expires_at}" }

      begin
        lock_token = lock(timeout)

        # puts lock_token && lock_token[:key]

        if lock_token
          begin
            res = yield
            unlock(lock_token[:key], lock_token[:lockid])
            return res
          rescue Exception
            unlock(lock_token[:key], lock_token[:lockid])
          end
        else
          # raise ResourceLocked if iteration >= config.retries
        end

        wait(iteration += 1)
      end until Time.now > expires_at

      raise Timeout
    rescue Redis::TimeoutError
      yield
    end

    def reset
      config.locks.each do |key|
        config.connection_pool.with do |redis|
          redis.del(key)
        end
      end
    end

    def remove
      Group.remove(@name)
    end

    private

    def lock(timeout)
      ttl = ((timeout || config.lock_timeout) * 1000).round
      lockid = SecureRandom.hex(20)
      # $stderr.puts "lock #{ttl} #{lockid}\n"
      config.connection_pool.with do |redis|
        config.locks.each do |key|
          if redis.client.call([:set, key, lockid, :nx, :px, ttl])
            config.logger.info(name) { "Lock #{key} was acquired for #{ttl}ms" }
            return { key: key, lockid: lockid }
          end
        end
      end

      return false
    end

    def unlock(key, lockid)
      config.connection_pool.with do |redis|
        if redis.call([:get, key]) == lockid
          redis.call([:del, key])
        end
      end
    end

    def wait(iteration)
      config.logger.debug(name) { "Sleeping for #{config.seconds_per_retry(iteration) * 1000}ms" }
      sleep(config.seconds_per_retry(iteration))
    end
  end
end
