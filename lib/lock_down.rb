if %w(development test).include?(ENV["RACK_ENV"])
  require "dotenv"
  Dotenv.load
end

require "lock_down/version"
require "lock_down/group"

module LockDown
  module_function

  ResourceLocked = Class.new(StandardError)
  Timeout = Class.new(StandardError)
  ConfigError = Class.new(StandardError)

  def config(group_name = :default)
    group = Group.find_or_create(group_name)

    group.config.tap do |c|
      yield(c) if block_given?
    end
  end

  def groups
    Group.all
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

    Group.find_or_create(group_name, options).run(timeout, &block)
  end

  def reset(group_name = :default)
    if group = Group.find(group_name)
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

    Group.find_or_create(group_name, options)
  end
end
