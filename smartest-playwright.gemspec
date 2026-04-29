# frozen_string_literal: true

core = Gem::Specification.load(File.expand_path("smartest.gemspec", __dir__))

Gem::Specification.new do |spec|
  spec.name = "smartest-playwright"
  spec.version = core.version
  spec.authors = core.authors

  spec.summary = "Playwright browser-test setup for Smartest."
  spec.description = "smartest-playwright adds a Smartest init command, fixture scaffold, and Playwright matcher integration for browser tests."
  spec.homepage = core.homepage
  spec.license = core.license
  spec.required_ruby_version = core.required_ruby_version

  spec.metadata = core.metadata.merge(
    "source_code_uri" => "https://github.com/YusukeIwaki/smartest/tree/main"
  )

  spec.files = Dir.chdir(__dir__) do
    Dir.glob(
      [
        "LICENSE",
        "README.md",
        "exe/smartest-playwright",
        "lib/smartest-playwright.rb",
        "lib/smartest/playwright.rb",
        "lib/smartest/playwright/**/*.rb",
        "smartest-playwright.gemspec"
      ]
    )
  end

  spec.bindir = "exe"
  spec.executables = ["smartest-playwright"]
  spec.require_paths = ["lib"]

  spec.add_dependency "playwright-ruby-client", ">= 1.59", "< 2.0"
  spec.add_dependency "smartest", "= #{core.version}"
end
