require "redis"
require "connection_pool"
require "logger"

require "lock_down/version"
require "lock_down/group"
require "lock_down/group_store"

module LockDown
  module_function

  Timeout = Class.new(StandardError)
  ConfigError = Class.new(StandardError)

  class Config
    include Singleton

    attr_accessor :connection_pool,
      :connection_pool_timeout,
      :redis_url,
      :redis_namespace,
      :pool_size,
      :logger

    def initialize
      self.redis_namespace = 'lock_down'
      self.pool_size = 25
      self.connection_pool_timeout = 0.5
      self.logger = Logger.new($stdout).tap do |l|
        l.formatter = proc do |severity, time, group_name, message|
          "#{time},#{severity},##{Process.pid},#{group_name}: #{message}\n"
        end
      end
    end
  end

  def configure
    config = Config.instance
    yield config

    unless config.redis_url || config.connection_pool
      raise ArgumentError, "Provide redis_url or connection_pool"
    end

    unless config.connection_pool
      config.connection_pool = ConnectionPool.new(size: config.pool_size, timeout: config.connection_pool_timeout) do
        Redis.new(url: config.redis_url)
      end
    end
  end

  def self.logger
    Config.instance.logger
  end

  def self.connection_pool
    Config.instance.connection_pool
  end

  def group(group_name = :default)
    group = GroupStore.find_or_create(group_name)

    group.tap do |group|
      yield(group)
    end
  end

  def groups
    GroupStore.all
  end

  # group, timeout, options
  def run(*args, &block)
    if args[0].is_a?(Hash)
      options = args[0]
      group_name = options.delete(:group) || :default
      timeout = options.delete(:timeout)
    else
      options = args[2] || {}
      group_name = args[0] || :default
      timeout = args[1]
    end

    GroupStore.find_or_create(group_name, options).run(timeout, &block)
  end

  def reset(group_name = :default)
    if group = GroupStore.find(group_name)
      group.reset
    end
  end

  # group_name, options
  def find_or_create_group(*args)
    if args[0].is_a?(Hash)
      options    = args[0]
      group_name = options.delete(:group) || :default
    else
      group_name = args[0] || :default
      options    = args[1] || {}
    end

    GroupStore.find_or_create(group_name, options)
  end
end
