# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lock_down/version"

Gem::Specification.new do |spec|
  spec.name          = "lock_down"
  spec.version       = LockDown::VERSION
  spec.authors       = ["Florin Lipan"]
  spec.email         = ["lipanski@gmail.com"]

  spec.summary       = %q{A centralized Redis-based lock to help you wait on throttled resources}
  spec.description   = %q{A centralized Redis-based lock to help you wait on throttled resources}
  spec.homepage      = "https://github.com/lipanski/lock_down"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "redis"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "minitest-stub-const"
  spec.add_development_dependency "m"
end
