# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pester/version'

Gem::Specification.new do |spec|
  spec.name          = 'pester'
  spec.version       = Pester::VERSION
  spec.authors       = ['Marc Bollinger']
  spec.email         = ['marc@lumoslabs.com']
  spec.summary       = 'Common block-based retry for external calls.'
  spec.description   = <<-EOD
                       |We found ourselves constantly wrapping network-facing calls with all kinds of bespoke,
                       | copied, and rewritten retry logic. This gem is an attempt to unify common behaviors,
                       | like simple retry, retry with linear backoff, and retry with exponential backoff.
EOD
  spec.homepage      = 'https://github.com/lumoslabs/pester'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)\//)
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.2'
end
