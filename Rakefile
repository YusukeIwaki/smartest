# frozen_string_literal: true

require "fileutils"
require_relative "lib/smartest/version"

task :test do
  ruby "-Ilib", "exe/smartest"
end

desc "Build gem packages"
task :build do
  FileUtils.mkdir_p("pkg")
  sh "gem build smartest.gemspec --output pkg/smartest-#{Smartest::VERSION}.gem"
  sh "gem build smartest-playwright.gemspec --output pkg/smartest-playwright-#{Smartest::VERSION}.gem"
end

desc "Run tests and build the gem package"
task verify: [:test, :build]

task default: :test
