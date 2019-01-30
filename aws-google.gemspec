lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aws/google/version'

Gem::Specification.new do |spec|
  spec.name          = 'aws-google'
  spec.version       = Aws::Google::VERSION
  spec.authors       = ['Will Jordan']
  spec.email         = ['will@code.org']

  spec.summary       = 'Use Google OAuth as an AWS credential provider.'
  spec.description   = 'Use Google OAuth as an AWS credential provider.'
  spec.homepage      = 'https://github.com/code-dot-org/aws-google'
  spec.license       = 'Apache-2.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-core', '~> 3'
  spec.add_dependency 'google-api-client', '~> 0.23'
  spec.add_dependency 'launchy' # Peer dependency of Google::APIClient::InstalledAppFlow

  spec.add_development_dependency 'activesupport'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'webmock'
end
