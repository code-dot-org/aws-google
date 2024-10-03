lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aws/google/version'

Gem::Specification.new do |spec|
  spec.required_ruby_version = '>= 3.0.5'
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

  spec.add_dependency 'aws-sdk-core', '~> 3.209.1'
  spec.add_dependency 'google-apis-core', '~> 0.15.1'
  spec.add_dependency 'launchy', '~> 3.0.1'

  spec.add_development_dependency 'activesupport', '~> 6.1.7.8'
  spec.add_development_dependency 'minitest', '~> 5.25.1'
  spec.add_development_dependency 'mocha', '~> 2.4.5'
  spec.add_development_dependency 'rake', '~> 13.2.1'
  spec.add_development_dependency 'timecop', '~> 0.9.10'
  spec.add_development_dependency 'webmock', '3.24.0'
end
