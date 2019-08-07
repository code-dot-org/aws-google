lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aws/google/version'

Gem::Specification.new do |spec|
  spec.name          = 'aws-google'
  spec.version       = Aws::Google::VERSION
  spec.authors       = ['Will Jordan']
  spec.email         = ['will@code.org']

  spec.summary       = 'Use Google OAuth as an AWS credential provider'
  spec.description   = 'Use Google OAuth as an AWS credential provider.'
  spec.homepage      = 'https://github.com/code-dot-org/aws-google'
  spec.license       = 'Apache-2.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-core', '~> 3'
  spec.add_dependency 'google-api-client', '~> 0.23'
  spec.add_dependency 'launchy', '~> 2'

  spec.add_development_dependency 'activesupport', '~> 5'
  spec.add_development_dependency 'bundler', '~> 1'
  spec.add_development_dependency 'minitest', '~> 5.10'
  spec.add_development_dependency 'mocha', '~> 1.5'
  spec.add_development_dependency 'rake', '~> 12'
  spec.add_development_dependency 'timecop', '~> 0.8'
  spec.add_development_dependency 'webmock', '~> 3.3'
end
