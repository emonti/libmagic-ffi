# frozen_string_literal: true

# Rakefile

begin
  require 'bundler/gem_tasks'
rescue LoadError
end

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/test_*.rb']
end

task default: :test
