require "dotenv"
Dotenv.load
ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "minitest/mock"
require "minitest/stub_const"
require "benchmark"
require "tempfile"
require "lock_down"

LockDown.configure do |c|
  c.redis_url = ENV.fetch("REDIS_URL")
  c.logger = Logger.new(IO::NULL)
end

MiniTest::Reporters.use!(Minitest::Reporters::SpecReporter.new)
