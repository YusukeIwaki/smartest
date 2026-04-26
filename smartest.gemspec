# frozen_string_literal: true

require_relative "lib/smartest/version"

Gem::Specification.new do |spec|
  spec.name = "smartest"
  spec.version = Smartest::VERSION
  spec.authors = ["Yusuke Iwaki"]

  spec.summary = "A small Ruby test runner with keyword-first fixtures."
  spec.description = "Smartest is a small Ruby test runner focused on readable top-level tests, explicit keyword-argument fixture dependencies, and optional fixture cleanup."
  spec.homepage = "https://github.com/YusukeIwaki/smartest"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/YusukeIwaki/smartest/issues",
    "documentation_uri" => "https://yusukeiwaki.github.io/smartest/",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/YusukeIwaki/smartest/tree/main"
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
        "test/**/*.rb"
      ]
    )
  end

  spec.bindir = "exe"
  spec.executables = ["smartest"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
end
