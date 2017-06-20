# LockDown

[![Gem Version](https://badge.fury.io/rb/lock_down.svg)](http://badge.fury.io/rb/lock_down)
[![Build Status](https://travis-ci.org/lipanski/slow-down.svg?branch=master)](https://travis-ci.org/lipanski/slow-down)

## Why would you want to slow down your requests?!

Some external APIs might be throttling your requests (or web scraping attempts) or your own infrastructure is not able to bear the load.
It sometimes pays off to be patient...

**LockDown** delays a call up until the point where you can afford to trigger it.
It relies on a Redis lock so it should be able to handle a cluster of servers all going for the same resource.
It's based on the `PX` and `NX` options of the Redis `SET` command, which should make it thread-safe.
Note that these options were introduced with Redis version 2.6.12.

## Usage

### Basic

```ruby
require "lock_down"

LockDown.config do |c|
  c.concurrency = 10   # Not more than 10 concurent clients
  c.lock_timeout = 10 # Should be the same or more than resource network timeout
  c.redis_url = "redis://localhost:6379/0" # or set the REDIS_URL environment variable
end

LockDown.run(5) do
  some_throttled_api_call # locking resource for 5 or less seconds
end
```

### Groups

**LockDown** can be configured for individual groups, which can be run in isolation:

```ruby
LockDown.config(:github) do |c|
  c.concurrency = 10
  c.lock_timeout = 10 # Should be the same or more than resource network timeout
end

LockDown.config(:twitter) do |c|
  c.concurrency = 10
  c.lock_timeout = 1
end

# Acquire a lock for the :github group
LockDown.run(:github) { ... }

# Acquire a lock for the :twitter group
LockDown.run(:twitter) { ... }
```

### Retrieve configuration

When called without a block, `LockDown.config` will return the configuration of the *default* group.
In order to fetch the configuration of a different group use `LockDown.config(:group_name)`.

### Defaults & available options

```ruby
LockDown.config do |c|
  # The allowed number of concurrent calls
  c.concurrency = 10

  # The number of seconds during which LockDown will try and acquire the resource
  # for a given call.
  c.acquire_timeout = 5

  # How many retries should be performed til the timeout is reached.
  c.retries = 30

  # The algorithm used to schedule the amount of time to wait between retries.
  # Available strategies: :linear, :inverse_exponential, :fibonacci or a class
  # extending LockDown::Strategy::Base.
  c.retry_strategy = :linear

  # Redis can be configured either directly, by setting a Redis instance to this
  # variable, or via the REDIS_URL environment variable or via the redis_url
  # setting.
  c.redis = nil

  # Configure Redis via the instance URL.
  c.redis_url = nil

  # The Redis namespace to apply to all locks.
  c.redis_namespace = :lock_down

  # The namespace to apply to the default group.
  # Individual groups will overwrite this with the group name.
  c.lock_namespace = :default

  # By default, the LockDown logger is disabled.
  # Set this to Logger::DEBUG, Logger::INFO or Logger::ERROR for logging various
  # runtime information.
  c.log_level = Logger::UNKNOWN
end
```


### Resetting the locks

If you ever need to reset the locks, you can do that for any group by calling:

```ruby
LockDown.reset(:group_name)
```

### Polling strategies

When a request is placed that can't access the lock right away, **LockDown** puts it to sleep and schedules it to wake up & try again for the amount of retries configured by the user (defaulting to 0 retries).

The spread of these *retry sessions* can be linear (default behaviour) or non-linear - in case you want to simulate different strategies:

1. **FIFO**: Inverse exponential series - set `LockDown.config { |c| c.retry_strategy = :inverse_exponential }`
2. **LIFO**: Fibonacci series - set `LockDown.config { |c| c.retry_strategy = :fibonacci }`

These polling strategies are just a proof of concept and their behaviour relies more on probabilities.

## Inspiration

- [Distributed locks using Redis](https://engineering.gosquared.com/distributed-locks-using-redis)
- [Redis SET Documentation](http://redis.io/commands/set)
- [mario-redis-lock](https://github.com/marioizquierdo/mario-redis-lock)
- [redlock-rb](https://github.com/antirez/redlock-rb)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/lipanski/lock_down/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
