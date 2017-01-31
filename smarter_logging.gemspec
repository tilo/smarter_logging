# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'smarter_logging/version'

Gem::Specification.new do |spec|
  spec.name          = "smarter_logging"
  spec.version       = SmarterLogging::VERSION
  spec.authors       = ["Tilo Sloboda"]
  spec.email         = ["tilo.sloboda@gmail.com"]

  spec.summary       = %q{Ruby Gem for smarter logging of key=value data}
  spec.description   = %q{Ruby Gem for smarter logging of key=value data in single-line format}
  spec.homepage      = "https://github.com/tilo/smarter_logging"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
