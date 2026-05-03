# frozen_string_literal: true

require_relative "lib/smartest/version"

Gem::Specification.new do |spec|
  spec.name = "smartest"
  spec.version = Smartest::VERSION
  spec.authors = ["Yusuke Iwaki"]

  spec.summary = "Pytest-style fixtures for Ruby."
  spec.description = "Smartest is a Ruby test runner with pytest-style fixture injection. Tests request fixtures using keyword arguments, fixtures can depend on other fixtures, and cleanup is registered only when needed."
  spec.homepage = "https://smartest-rb.vercel.app"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/YusukeIwaki/smartest/issues",
    "changelog_uri" => "https://github.com/YusukeIwaki/smartest/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://smartest-rb.vercel.app/docs/fixtures",
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
