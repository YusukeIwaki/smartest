# frozen_string_literal: true

require_relative "lib/smartest/version"

Gem::Specification.new do |spec|
  spec.name = "smartest"
  spec.version = Smartest::VERSION
  spec.authors = ["Yusuke Iwaki"]

  spec.summary = "A Ruby test runner with pytest-style fixtures and Playwright-friendly browser testing."
  spec.description = <<~TEXT
    Smartest is a Ruby test runner that brings pytest-style fixture injection
    to Ruby. Tests declare dependencies with keyword arguments, fixtures can
    depend on other fixtures, and cleanup is handled explicitly when needed.

    Smartest is designed for readable Ruby tests, Rails system tests, and
    Playwright-powered browser testing.
  TEXT
  spec.homepage = "https://smartest-rb.vercel.app"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/YusukeIwaki/smartest/issues",
    "changelog_uri" => "https://github.com/YusukeIwaki/smartest/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://smartest-rb.vercel.app/docs",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/YusukeIwaki/smartest"
  }

  spec.files = Dir.chdir(__dir__) do
    Dir.glob(
      [
        "CHANGELOG.md",
        "DEVELOPMENT.md",
        "Gemfile",
        "LICENSE",
        "README.md",
        "Rakefile",
        "SMARTEST_DESIGN.md",
        "exe/*",
        "lib/**/*.rb",
        "smartest.gemspec",
        "smartest/**/*.rb"
      ]
    )
  end

  spec.bindir = "exe"
  spec.executables = ["smartest"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
end
