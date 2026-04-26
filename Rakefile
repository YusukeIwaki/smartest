# frozen_string_literal: true

require "bundler/gem_tasks"

task :test do
  ruby "-Ilib", "exe/smartest", "test/**/*_test.rb"
end

desc "Run tests and build the gem package"
task verify: [:test, :build]

task default: :test
