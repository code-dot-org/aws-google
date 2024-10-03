require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']

  # Enable detailed warnings
  t.ruby_opts << '-W2'
  t.verbose = true # Shows the detailed output of each test
end

task default: :test
